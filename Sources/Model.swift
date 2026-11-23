import SwiftUI
import AppKit

final class CancelToken {
    private let lock = NSLock()
    private var flag = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func cancel() { lock.lock(); flag = true; lock.unlock() }
}

/// Limita las actualizaciones de progreso a ~10 por segundo.
final class Throttle {
    private var last = Date.distantPast
    func ready() -> Bool {
        let now = Date()
        if now.timeIntervalSince(last) > 0.1 { last = now; return true }
        return false
    }
}

enum Screen { case waiting, home, comparing, preview, copying, done }

enum DedupeStatus {
    case idle
    case running(Double, String)
    case found(Int, Int64)      // found, waiting for the user's OK
    case removed(Int, Int64)
    case clean
    case failed(String)
}

struct CopyResult {
    var copied = 0
    var bytes: Int64 = 0
    var errors: [String] = []
    var cancelled = false
}

@MainActor
final class AppModel: ObservableObject {
    @Published var theme: Theme { didSet { UserDefaults.standard.set(theme.id, forKey: "theme"); onThemeChange?() } }
    @Published var autoDedupe: Bool { didSet { UserDefaults.standard.set(autoDedupe, forKey: "autoDedupe") } }
    @Published var musicFolder: URL { didSet { UserDefaults.standard.set(musicFolder.path, forKey: "musicFolder") } }

    @Published var screen: Screen = .waiting
    @Published var device: DeviceInfo?
    @Published var dedupe: DedupeStatus = .idle
    @Published var lastRemoved: [RemovedItem] = []
    @Published var showRemoved = false
    @Published var progress: Double = 0
    @Published var progressTitle = ""
    @Published var progressDetail = ""
    @Published var plan = SyncPlan()
    @Published var result = CopyResult()
    @Published var macSongCount: Int?
    @Published var errorMessage: String?

    var onThemeChange: (() -> Void)?
    private var busy = false
    private var token = CancelToken()
    private let macIndex = HashIndex(name: "mac")
    private var ipodIndex: HashIndex?

    init() {
        let d = UserDefaults.standard
        theme = Theme.with(id: d.string(forKey: "theme") ?? Theme.basico.id)
        autoDedupe = d.object(forKey: "autoDedupe") as? Bool ?? false
        let def = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music")
        musicFolder = d.string(forKey: "musicFolder").map { URL(fileURLWithPath: $0) } ?? def
    }

    // MARK: Conexión

    func connected(_ vol: URL) {
        if device?.url == vol { return }
        let uuid = (try? vol.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString) ?? nil
        ipodIndex = HashIndex(name: "ipod-" + (uuid ?? vol.lastPathComponent))
        dedupe = .idle
        screen = .home
        refreshInfo(vol) { [weak self] in self?.runDedupe() }
        countMacSongs()
    }

    func disconnected(_ vol: URL) {
        guard device?.url == vol else { return }
        token.cancel()
        device = nil
        screen = .waiting
    }

    func refreshInfo(_ vol: URL? = nil, then: (() -> Void)? = nil) {
        guard let vol = vol ?? device?.url else { return }
        Task.detached {
            let info = Scanner.deviceInfo(at: vol)
            await MainActor.run {
                self.device = info
                then?()
            }
        }
    }

    func countMacSongs() {
        let folder = musicFolder
        Task.detached {
            let n = Scanner.files(under: folder, onlyMusic: true).count
            await MainActor.run { self.macSongCount = n }
        }
    }

    // MARK: Duplicates inside the iPod

    /// Looks for identical copies. Removes them right away only if the user turned on "remove automatically";
    /// otherwise shows how many there are and waits for the user to press "Remove".
    func runDedupe(remove: Bool? = nil) {
        guard let vol = device?.url, let index = ipodIndex, !busy else { return }
        let doRemove = remove ?? autoDedupe
        busy = true
        token = CancelToken()
        let tok = token
        dedupe = .running(0, "")
        let th = Throttle()
        Task.detached {
            let files = Scanner.files(under: vol, onlyMusic: true)
            let groups = Dupes.groups(files, index: index, progress: { p, name in
                if th.ready() { Task { @MainActor in self.dedupe = .running(p, name) } }
            }, cancelled: { tok.isCancelled })
            if !doRemove {
                let extra = groups.reduce(Int64(0)) { a, g in a + g.dropFirst().reduce(Int64(0)) { $0 + $1.size } }
                let n = groups.reduce(0) { $0 + $1.count - 1 }
                await MainActor.run {
                    self.busy = false
                    if tok.isCancelled { self.dedupe = .idle; return }
                    self.dedupe = n == 0 ? .clean : .found(n, extra)
                }
                return
            }
            var removed: [RemovedItem] = []
            let fm = FileManager.default
            for g in groups where !tok.isCancelled {
                let keep = Dupes.keeper(of: g, volume: vol)
                guard fm.fileExists(atPath: keep.path) else { continue }
                for f in g where f.path != keep.path && f.path.hasPrefix(vol.path + "/") {
                    do {
                        try fm.removeItem(at: f.url)
                        let ad = f.url.deletingLastPathComponent().appendingPathComponent("._" + f.url.lastPathComponent)
                        try? fm.removeItem(at: ad)
                        index.forget(f.path)
                        removed.append(RemovedItem(removed: f.path, kept: keep.path, size: f.size, date: Date()))
                    } catch { /* si no se puede borrar, se deja como está */ }
                }
            }
            index.save()
            RemovedLog.append(removed)
            let bytes = removed.reduce(Int64(0)) { $0 + $1.size }
            let gone = removed
            await MainActor.run {
                self.busy = false
                if tok.isCancelled { self.dedupe = .idle; return }
                self.lastRemoved = gone
                self.dedupe = gone.isEmpty ? .clean : .removed(gone.count, bytes)
                if !gone.isEmpty { self.refreshInfo() }
            }
        }
    }

    // MARK: Sincronizar

    func startSync() {
        guard let dev = device, let ipodIndex, !busy else { return }
        guard FileManager.default.fileExists(atPath: musicFolder.path) else {
            errorMessage = L("No encuentro tu carpeta de música en \(musicFolder.path). Elige otra con “Cambiar”.",
                             "Can't find your music folder at \(musicFolder.path). Pick another one with “Change”.")
            return
        }
        busy = true
        token = CancelToken()
        let tok = token
        screen = .comparing
        progress = 0
        progressTitle = L("Comparando canciones…", "Comparing songs…")
        progressDetail = ""
        let folder = musicFolder, macIndex = macIndex, th = Throttle()
        Task.detached {
            let mac = Scanner.files(under: folder, onlyMusic: true)
            let ipod = Scanner.files(under: dev.url, onlyMusic: true)
            let free = (try? dev.url.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity).flatMap { $0 }.map(Int64.init) ?? dev.free
            let plan = Planner.plan(macRoot: folder, macFiles: mac, ipodFiles: ipod, macIndex: macIndex,
                                    ipodIndex: ipodIndex, free: free,
                                    progress: { p, n in
                                        if th.ready() { Task { @MainActor in self.progress = p; self.progressDetail = n } }
                                    }, cancelled: { tok.isCancelled })
            await MainActor.run {
                self.busy = false
                if tok.isCancelled { if self.device != nil { self.screen = .home }; return }
                self.plan = plan
                self.macSongCount = mac.count
                self.screen = .preview
            }
        }
    }

    func confirmCopy() {
        guard let dev = device, let ipodIndex, !busy, plan.fits, !plan.items.isEmpty else { return }
        busy = true
        token = CancelToken()
        let tok = token
        screen = .copying
        progress = 0
        let items = plan.items
        let total = plan.bytes
        let th = Throttle()
        Task.detached {
            var r = CopyResult()
            var copiedBytes: Int64 = 0
            let base = destinationFolder(on: dev.url)
            for (i, it) in items.enumerated() {
                if tok.isCancelled { r.cancelled = true; break }
                let name = it.relative
                Task { @MainActor in
                    self.progressTitle = L("Copiando \(i + 1) de \(items.count)", "Copying \(i + 1) of \(items.count)")
                    self.progressDetail = name
                }
                let dst = Copier.uniqueDestination(base.appendingPathComponent(it.relative))
                do {
                    let hash = try Copier.copy(it.source.url, to: dst, chunk: { n in
                        copiedBytes += n
                        if th.ready() { let p = Double(copiedBytes) / Double(max(total, 1)); Task { @MainActor in self.progress = p } }
                    }, cancelled: { tok.isCancelled })
                    let v = try? dst.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    ipodIndex.set(FileEntry(url: dst, size: Int64(v?.fileSize ?? 0),
                                            mtime: v?.contentModificationDate?.timeIntervalSince1970 ?? 0), full: hash)
                    r.copied += 1
                    r.bytes += it.source.size
                } catch is CancellationError {
                    r.cancelled = true
                    break
                } catch {
                    r.errors.append(error.localizedDescription)
                }
            }
            ipodIndex.save()
            let final = r
            await MainActor.run {
                self.busy = false
                self.result = final
                if self.device != nil {
                    self.screen = .done
                    self.refreshInfo()
                }
            }
        }
    }

    func cancelJob() { token.cancel() }

    func backHome() { if device != nil { screen = .home } else { screen = .waiting } }

    // MARK: Expulsar

    func eject(then: @escaping () -> Void) {
        guard let vol = device?.url, !busy else { return }
        Task.detached {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: vol)
                await MainActor.run { self.disconnected(vol); then() }
            } catch {
                await MainActor.run {
                    self.errorMessage = L("No se pudo expulsar: \(error.localizedDescription). Cierra cualquier ventana o app que esté usando el iPod e intenta de nuevo.",
                                          "Couldn't eject: \(error.localizedDescription). Close any window or app using the iPod and try again.")
                }
            }
        }
    }

    func chooseMusicFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.allowsMultipleSelection = false
        p.directoryURL = musicFolder
        p.prompt = L("Usar esta carpeta", "Use this folder")
        p.message = L("Elige la carpeta donde guardas tu música en la Mac", "Choose the folder where you keep your music on this Mac")
        NSApp.activate(ignoringOtherApps: true)
        if p.runModal() == .OK, let u = p.url {
            musicFolder = u
            countMacSongs()
        }
    }
}
