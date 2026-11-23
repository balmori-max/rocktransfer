import AppKit
import SwiftUI
import ServiceManagement

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // sólo en la barra de menú, sin ícono en el Dock
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = AppModel()
    var window: NSWindow?
    var status: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        // Una sola copia de la app a la vez
        let me = NSRunningApplication.current
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != me }) {
            NSApp.terminate(nil)
            return
        }

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let img = NSImage(systemSymbolName: "ipod", accessibilityDescription: "RockSync")
            ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: "RockSync")
        img?.isTemplate = true
        status.button?.image = img
        let menu = NSMenu()
        menu.delegate = self
        status.menu = menu

        model.onThemeChange = { [weak self] in self?.applyThemeToWindow() }

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
            guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            MainActor.assumeIsolated { self?.volumeMounted(url) }
        }
        nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] note in
            guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            MainActor.assumeIsolated { self?.model.disconnected(url) }
        }

        // ¿Ya estaba conectado al arrancar?
        let vols = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
        if let v = vols.first(where: { Scanner.isRockbox($0) }) {
            volumeMounted(v)
        }
        // First launch: open at login (so the window can pop up when the iPod is plugged in) and show the window.
        let d = UserDefaults.standard
        if !d.bool(forKey: "didFirstLaunch") {
            d.set(true, forKey: "didFirstLaunch")
            try? SMAppService.mainApp.register()
            showWindow()
        }
        if CommandLine.arguments.contains("--show") { showWindow() }
    }

    func volumeMounted(_ url: URL) {
        // Espera un momento a que el disco termine de montarse
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, Scanner.isRockbox(url) else { return }
            self.model.connected(url)
            self.showWindow()
        }
    }

    // MARK: Ventana

    func showWindow() {
        if window == nil {
            let root = RootView(close: { [weak self] in self?.window?.close() }).environmentObject(model)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.title = "RockSync"
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: root)
            w.delegate = self
            w.center()
            window = w
        }
        applyThemeToWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func applyThemeToWindow() {
        guard let w = window else { return }
        w.appearance = NSAppearance(named: model.theme.isLight ? .aqua : .darkAqua)
        w.backgroundColor = NSColor(model.theme.bar)
    }

    // MARK: Menú de la barra

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let d = model.device {
            let i = NSMenuItem(title: L("\(d.name) conectado", "\(d.name) connected"), action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(i)
        } else {
            let i = NSMenuItem(title: L("Sin iPod conectado", "No iPod connected"), action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(i)
        }
        menu.addItem(item(L("Abrir RockSync", "Open RockSync"), #selector(openWindow)))
        menu.addItem(.separator())

        let themes = NSMenu()
        for t in Theme.all {
            let it = item(t.name, #selector(pickTheme(_:)))
            it.representedObject = t.id
            it.state = t == model.theme ? .on : .off
            themes.addItem(it)
        }
        let tItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        tItem.submenu = themes
        menu.addItem(tItem)

        menu.addItem(item(L("Carpeta de música…", "Music folder…"), #selector(chooseFolder)))
        let auto = item(L("Quitar canciones repetidas automáticamente", "Remove duplicate songs automatically"), #selector(toggleAuto))
        auto.state = model.autoDedupe ? .on : .off
        menu.addItem(auto)
        let login = item(L("Abrir al iniciar sesión", "Open at login"), #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item(L("Salir de RockSync", "Quit RockSync"), #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc func openWindow() { showWindow() }
    @objc func pickTheme(_ s: NSMenuItem) { if let id = s.representedObject as? String { model.theme = Theme.with(id: id) } }
    @objc func chooseFolder() { model.chooseMusicFolder() }
    @objc func toggleAuto() { model.autoDedupe.toggle() }
    @objc func toggleLogin() {
        let s = SMAppService.mainApp
        if s.status == .enabled { try? s.unregister() } else { try? s.register() }
    }
    @objc func quit() { NSApp.terminate(nil) }
}
