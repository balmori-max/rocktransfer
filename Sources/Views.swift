import SwiftUI

let mono = Font.system(size: 12, weight: .regular, design: .monospaced)
/// Set by the artwork renderer: AppKit-backed controls (Menu, ScrollView) don't render into images.
nonisolated(unsafe) var renderMode = false

// MARK: - Botones

struct PrimaryButton: View {
    @EnvironmentObject var m: AppModel
    let title: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(m.theme.btnText)
                .padding(.horizontal, 20).frame(height: 32)
                .background(m.theme.button, in: RoundedRectangle(cornerRadius: 8))
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain).disabled(!enabled)
        .keyboardShortcut(.defaultAction)
    }
}

struct GhostButton: View {
    @EnvironmentObject var m: AppModel
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(m.theme.fg)
                .padding(.horizontal, 14).frame(height: 32)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(m.theme.line, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LinkButton: View {
    @EnvironmentObject var m: AppModel
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(m.theme.link)
        }.buttonStyle(.plain)
    }
}

// MARK: - Ilustración del iPod

struct IPodIllustration: View {
    let theme: Theme
    var rows = [L("Archivos", "Files"), L("Base de datos", "Database"), L("Reproduciendo", "Now Playing"), L("Configuración", "Settings")]
    var selected = 1
    var body: some View {
        let silver = theme.isLight
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: silver ? [Color(hex: 0xF2F2F4), Color(hex: 0xC9C9CE)] : [Color(hex: 0x3A3A3E), Color(hex: 0x18181B)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(silver ? Color(hex: 0xB9B9BE) : Color(hex: 0x4A4A50), lineWidth: 1))
            VStack(spacing: 0) {
                // Pantalla con un menú de Rockbox en los colores del theme
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROCKBOX").font(.system(size: 6, design: .monospaced)).foregroundStyle(theme.muted)
                        .padding(.leading, 4)
                    Rectangle().fill(theme.line).frame(height: 0.6)
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        Text(r)
                            .font(.system(size: 7, weight: i == selected ? .bold : .regular))
                            .foregroundStyle(i == selected ? theme.selText : theme.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4).frame(height: 11)
                            .background(i == selected ? AnyShapeStyle(theme.selector) : AnyShapeStyle(Color.clear),
                                        in: RoundedRectangle(cornerRadius: 2))
                    }
                    Spacer(minLength: 0)
                }
                .padding(3)
                .frame(width: 98, height: 74)
                .background(theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(3)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 4))
                .padding(.top, 14)
                Spacer()
                ZStack {
                    Circle().fill(silver ? Color.white : Color(hex: 0x232326))
                        .overlay(Circle().stroke(silver ? Color(hex: 0xC7C7CC) : Color(hex: 0x4A4A50)))
                    Circle().fill(silver ? Color(hex: 0xF2F2F4) : Color(hex: 0x2E2E32)).frame(width: 32, height: 32)
                        .overlay(Circle().stroke(silver ? Color(hex: 0xC7C7CC) : Color(hex: 0x4A4A50)))
                    Text("MENU").font(.system(size: 8)).foregroundStyle(Color(hex: 0x8E8E93)).offset(y: -30)
                }
                .frame(width: 88, height: 88)
                .padding(.bottom, 18)
            }
        }
        .frame(width: 132, height: 220)
        .accessibilityLabel(L("iPod classic mostrando Rockbox", "iPod classic running Rockbox"))
    }
}

// MARK: - Raíz

struct RootView: View {
    @EnvironmentObject var m: AppModel
    var close: () -> Void

    var body: some View {
        let t = m.theme
        VStack(spacing: 0) {
            // Barra de título (los botones rojo/amarillo/verde los pone macOS)
            HStack {
                Spacer()
                Text("ROCKTRANSFER").font(.system(size: 11, design: .monospaced)).tracking(1.5).foregroundStyle(t.muted)
                Spacer()
            }
            .frame(height: 40)
            .overlay(alignment: .trailing) {
                if renderMode { Image(systemName: "paintpalette").foregroundStyle(t.muted).padding(.trailing, 16) } else {
                Menu {
                    ForEach(Theme.all) { th in
                        Button { m.theme = th } label: {
                            if th == m.theme { Label(th.name, systemImage: "checkmark") } else { Text(th.name) }
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette").foregroundStyle(t.muted)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .padding(.trailing, 16)
                .help(L("Cambiar theme", "Change theme"))
                }
            }
            .background(t.bar)

            Group {
                switch m.screen {
                case .waiting: WaitingView()
                case .home: HomeView()
                case .comparing: ProgressScreen(cancelTitle: L("Cancelar", "Cancel"))
                case .preview: PreviewView()
                case .copying: ProgressScreen(cancelTitle: L("Detener", "Stop"))
                case .done: DoneView(close: close)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 760, height: 540)
        .background(t.bg)
        .foregroundStyle(t.fg)
        .preferredColorScheme(t.isLight ? .light : .dark)
        .sheet(isPresented: $m.showRemoved) { RemovedListView() }
        .alert(L("Aviso", "Notice"), isPresented: Binding(get: { m.errorMessage != nil }, set: { if !$0 { m.errorMessage = nil } })) {
            Button("OK") { m.errorMessage = nil }
        } message: { Text(m.errorMessage ?? "") }
    }
}

struct Footer<Content: View>: View {
    @EnvironmentObject var m: AppModel
    var note: String
    @ViewBuilder var buttons: Content
    var body: some View {
        HStack(spacing: 10) {
            Text(note).font(.system(size: 12)).foregroundStyle(m.theme.muted).lineLimit(1).truncationMode(.middle)
            Spacer()
            buttons
        }
        .padding(.horizontal, 22).frame(height: 58)
        .background(m.theme.bar)
        .overlay(alignment: .top) { Rectangle().fill(m.theme.line).frame(height: 1) }
    }
}

// MARK: - Esperando

struct WaitingView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            IPodIllustration(theme: m.theme, rows: [L("Archivos", "Files"), L("Esperando…", "Waiting…"), L("Reproduciendo", "Now Playing"), L("Configuración", "Settings")])
            Text(L("Conecta tu iPod con Rockbox", "Plug in your Rockbox iPod")).font(.system(size: 24, weight: .heavy))
            Text(L("Esta ventana se abrirá sola cuando aparezca en la Mac.", "This window opens by itself when it shows up on your Mac."))
                .font(.system(size: 13)).foregroundStyle(m.theme.muted)
            Text(L("RockTransfer vive en la barra de menú (arriba a la derecha).", "RockTransfer lives in the menu bar (top right)."))
                .font(.system(size: 12)).foregroundStyle(m.theme.muted)
            Spacer()
        }
    }
}

// MARK: - Inicio

struct HomeView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let t = m.theme
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 32) {
                IPodIllustration(theme: t).padding(.top, 6)
                VStack(alignment: .leading, spacing: 16) {
                    if let d = m.device {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ROCKBOX \(d.rockboxVersion) · \(d.model.uppercased())")
                                .font(.system(size: 11, design: .monospaced)).tracking(1.5).foregroundStyle(t.muted)
                            Text(d.name).font(.system(size: 30, weight: .heavy)).tracking(-0.5)
                                .shadow(color: t.glow ?? .clear, radius: t.glow == nil ? 0 : 7)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(formatBytes(d.free)).font(.system(size: 20, weight: .bold, design: .monospaced))
                                Text(L("libres de \(formatBytes(d.total))", "free of \(formatBytes(d.total))")).font(.system(size: 13)).foregroundStyle(t.muted)
                            }
                            StorageBar(info: d)
                        }
                        VStack(spacing: 0) {
                            ForEach(Category.allCases, id: \.self) { c in
                                CategoryRow(category: c, info: d, selected: c == .music)
                            }
                        }
                        DedupeBanner()
                    } else {
                        Text(L("Leyendo el iPod…", "Reading the iPod…")).foregroundStyle(t.muted)
                    }
                }
            }
            .padding(.horizontal, 36).padding(.top, 20)
            Spacer(minLength: 0)
            Footer(note: footerNote) {
                LinkButton(title: L("Cambiar", "Change")) { m.chooseMusicFolder() }
                Spacer().frame(width: 6)
                GhostButton(title: L("Expulsar", "Eject")) { m.eject {} }
                PrimaryButton(title: L("Sincronizar", "Sync"), enabled: !isBusy) { m.startSync() }
            }
        }
    }
    var isBusy: Bool { if case .running = m.dedupe { return true }; return false }
    var footerNote: String {
        let n = m.macSongCount.map { L(" · \($0) canciones", " · \($0) songs") } ?? ""
        return L("Origen: ", "From: ") + "\(m.musicFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))\(n)"
    }
}

struct StorageBar: View {
    @EnvironmentObject var m: AppModel
    let info: DeviceInfo
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                Rectangle().fill(m.theme.selector).frame(width: width(.music, g.size.width))
                Rectangle().fill(m.theme.fg.opacity(0.7)).frame(width: width(.photos, g.size.width))
                Rectangle().fill(m.theme.fg.opacity(0.45)).frame(width: width(.videos, g.size.width))
                Rectangle().fill(m.theme.fg.opacity(0.25)).frame(width: width(.other, g.size.width))
                Spacer(minLength: 0)
            }
            .background(m.theme.line)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 8)
        .accessibilityLabel(L("\(formatBytes(info.used)) usados de \(formatBytes(info.total))", "\(formatBytes(info.used)) used of \(formatBytes(info.total))"))
    }
    func width(_ c: Category, _ w: CGFloat) -> CGFloat {
        let b = Double(info.bytes[c] ?? 0)
        return b <= 0 ? 0 : max(3, w * b / Double(max(info.total, 1)))
    }
}

struct CategoryRow: View {
    @EnvironmentObject var m: AppModel
    let category: Category
    let info: DeviceInfo
    let selected: Bool
    var body: some View {
        let t = m.theme
        let bytes = formatBytes(info.bytes[category] ?? 0)
        let detail = category == .other ? L("Rockbox, sistema · ", "Rockbox, system · ") + bytes : "\((info.counts[category] ?? 0).formatted()) · \(bytes)"
        HStack {
            Text(category.title).font(.system(size: 14, weight: selected ? .bold : .regular))
            Spacer()
            Text(detail).font(.system(size: 12, weight: selected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(selected ? t.selText : t.muted)
        }
        .foregroundStyle(selected ? t.selText : t.fg)
        .padding(.horizontal, 10).frame(height: 34)
        .background(selected ? AnyShapeStyle(t.selector) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .bottom) {
            if !selected && category != .other { Rectangle().fill(t.line).frame(height: 1) }
        }
    }
}

struct DedupeBanner: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let t = m.theme
        HStack(spacing: 10) {
            switch m.dedupe {
            case .idle:
                EmptyView()
            case .found(let n, let b):
                Image(systemName: "doc.on.doc").foregroundStyle(t.link)
                Text(L("Hay \(n) copias repetidas · \(formatBytes(b))", "\(n) duplicate copies · \(formatBytes(b))")).font(.system(size: 12))
                Spacer()
                LinkButton(title: L("Quitar siempre", "Always remove")) { m.autoDedupe = true; m.runDedupe(remove: true) }
                LinkButton(title: L("Quitar", "Remove")) { m.runDedupe(remove: true) }
            case .running(let p, let name):
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Buscando canciones repetidas… ", "Looking for duplicate songs… ") + "\(Int(p * 100))%").font(.system(size: 12))
                    Text(name).font(.system(size: 10, design: .monospaced)).foregroundStyle(t.muted).lineLimit(1)
                }
                Spacer()
            case .removed(let n, let b):
                Image(systemName: "checkmark.circle").foregroundStyle(t.link)
                Text(L("Quité \(n) copias repetidas · liberé \(formatBytes(b))", "Removed \(n) duplicate copies · freed \(formatBytes(b))")).font(.system(size: 12))
                Spacer()
                LinkButton(title: L("Ver lista", "See list")) { m.showRemoved = true }
            case .clean:
                Image(systemName: "checkmark.circle").foregroundStyle(t.link)
                Text(L("Sin canciones repetidas en el iPod", "No duplicate songs on the iPod")).font(.system(size: 12))
                Spacer()
            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle").foregroundStyle(t.link)
                Text(msg).font(.system(size: 12))
                Spacer()
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 40)
        .background(t.soft, in: RoundedRectangle(cornerRadius: 8))
        .opacity(isHidden ? 0 : 1)
    }
    var isHidden: Bool { if case .idle = m.dedupe { return true }; return false }
}

struct RemovedListView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let t = m.theme
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Copias repetidas que quité", "Duplicate copies removed")).font(.system(size: 18, weight: .bold))
            Text(L("Siempre se conservó una copia de cada canción. Esta lista también queda guardada en ~/Library/Application Support/RockTransfer/removed-duplicates.json", "One copy of every song was always kept. This list is also saved in ~/Library/Application Support/RockTransfer/removed-duplicates.json"))
                .font(.system(size: 12)).foregroundStyle(t.muted)
            List(m.lastRemoved) { r in
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Quitada: ", "Removed: ") + short(r.removed)).font(.system(size: 12))
                    Text(L("Se conserva: ", "Kept: ") + short(r.kept)).font(.system(size: 11)).foregroundStyle(t.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bar, in: RoundedRectangle(cornerRadius: 8))
            HStack { Spacer(); PrimaryButton(title: L("Listo", "Done")) { m.showRemoved = false } }
        }
        .padding(24)
        .frame(width: 620, height: 440)
        .background(t.bg)
        .foregroundStyle(t.fg)
    }
    func short(_ p: String) -> String {
        guard let vol = m.device?.url.path, p.hasPrefix(vol) else { return p }
        return String(p.dropFirst(vol.count + 1))
    }
}

// MARK: - Progreso

struct ProgressScreen: View {
    @EnvironmentObject var m: AppModel
    var cancelTitle: String
    var body: some View {
        let t = m.theme
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle().stroke(t.line, lineWidth: 6)
                    Circle().trim(from: 0, to: max(0.02, m.progress))
                        .stroke(t.selector, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(m.progress * 100))%").font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .frame(width: 70, height: 70)
                Text(m.progressTitle).font(.system(size: 22, weight: .heavy))
                    .shadow(color: t.glow ?? .clear, radius: t.glow == nil ? 0 : 7)
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(t.line)
                            Capsule().fill(t.selector).frame(width: g.size.width * m.progress)
                        }
                    }.frame(height: 8)
                    Text(m.progressDetail).font(mono).foregroundStyle(t.muted).lineLimit(1).truncationMode(.middle)
                }
                .frame(width: 520)
                Text(m.screen == .copying ? L("No desconectes el iPod. Cada canción se verifica después de copiarla.", "Don't unplug the iPod. Every song is verified after it's copied.")
                                          : L("La primera vez tarda más: estoy sacando la huella de cada canción. Después será rápido.", "The first time takes longer: every song gets fingerprinted. After that it's fast."))
                    .font(.system(size: 12)).foregroundStyle(t.muted)
                Spacer()
            }
            Footer(note: "") { GhostButton(title: cancelTitle) { m.cancelJob() } }
        }
    }
}

// MARK: - Antes de copiar

struct PreviewView: View {
    @EnvironmentObject var m: AppModel
    var destName: String { m.device.map { destinationFolder(on: $0.url).lastPathComponent } ?? "Music" }
    var body: some View {
        let t = m.theme
        let p = m.plan
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.items.isEmpty ? L("Todo está al día", "Everything is up to date") : L("Listo para copiar", "Ready to copy")).font(.system(size: 24, weight: .heavy))
                        .shadow(color: t.glow ?? .clear, radius: t.glow == nil ? 0 : 7)
                    Text(L("Comparé tus canciones con las del iPod por su contenido (huella SHA-256), no por su nombre.", "Songs were compared by their content (SHA-256 fingerprint), not by their name."))
                        .font(.system(size: 13)).foregroundStyle(t.muted)
                }
                HStack(spacing: 12) {
                    Stat(label: L("Canciones nuevas", "New songs"), value: "\(p.items.count)", accent: true)
                    Stat(label: L("Tamaño", "Size"), value: formatBytes(p.bytes))
                    Stat(label: L("¿Caben?", "Fits?"), value: p.fits ? L("Sí", "Yes") : "No",
                         sub: p.fits ? L("Quedarán \(formatBytes(p.free - p.bytes)) libres", "\(formatBytes(p.free - p.bytes)) will be left") : L("Faltan \(formatBytes(p.bytes - p.free + 50_000_000))", "Needs \(formatBytes(p.bytes - p.free + 50_000_000)) more"))
                }
                if !p.items.isEmpty {
                    let rows = VStack(spacing: 0) {
                            ForEach(p.items.prefix(300)) { it in
                                HStack {
                                    Text(it.relative).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Text(formatBytes(it.source.size)).font(mono).foregroundStyle(t.muted)
                                }
                                .padding(.horizontal, 12).frame(height: 30)
                                .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }
                            }
                        }
                    Group {
                        if renderMode { rows.frame(height: 210, alignment: .top).clipped() } else { ScrollView { rows } }
                    }
                    .background(t.bar.opacity(t.isLight ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Spacer()
                }
                Text(L("Omitidas: \(p.alreadyOnIPod) ya están en el iPod · \(p.macDuplicates) repetidas en tu Mac (con otro nombre). No se borra nada.", "Skipped: \(p.alreadyOnIPod) already on the iPod · \(p.macDuplicates) duplicates on your Mac (under another name). Nothing is deleted."))
                    .font(.system(size: 12)).foregroundStyle(t.muted)
            }
            .padding(.horizontal, 36).padding(.top, 20).padding(.bottom, 14)
            Footer(note: L("Se copian a /\(destName) del iPod, respetando tus carpetas", "Copied to /\(destName) on the iPod, keeping your folders")) {
                GhostButton(title: p.items.isEmpty ? L("Volver", "Back") : L("Cancelar", "Cancel")) { m.backHome() }
                if !p.items.isEmpty {
                    PrimaryButton(title: L("Copiar \(p.items.count) canciones", "Copy \(p.items.count) songs"), enabled: p.fits) { m.confirmCopy() }
                }
            }
        }
    }
}

struct Stat: View {
    @EnvironmentObject var m: AppModel
    let label: String
    let value: String
    var sub: String? = nil
    var accent = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(m.theme.muted)
            Text(value).font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(accent ? m.theme.link : m.theme.fg)
            if let sub { Text(sub).font(.system(size: 11)).foregroundStyle(m.theme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(m.theme.bar.opacity(m.theme.isLight ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(m.theme.line, lineWidth: 1))
    }
}

// MARK: - Listo

struct DoneView: View {
    @EnvironmentObject var m: AppModel
    var close: () -> Void
    var body: some View {
        let t = m.theme
        let r = m.result
        VStack(spacing: 0) {
            HStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        Circle().fill(t.button)
                        Image(systemName: r.errors.isEmpty ? "checkmark" : "exclamationmark")
                            .font(.system(size: 22, weight: .bold)).foregroundStyle(t.btnText)
                    }.frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(r.cancelled ? L("Copia detenida: \(r.copied) canciones", "Stopped: \(r.copied) songs copied") : L("\(r.copied) canciones copiadas", "\(r.copied) songs copied"))
                            .font(.system(size: 28, weight: .heavy))
                            .shadow(color: t.glow ?? .clear, radius: t.glow == nil ? 0 : 7)
                        Text(formatBytes(r.bytes) + L(" · verificadas · sin duplicados", " · verified · no duplicates"))
                            .font(mono).foregroundStyle(t.muted)
                        if !r.errors.isEmpty {
                            Text(L("\(r.errors.count) con problema: ", "\(r.errors.count) failed: ") + (r.errors.first ?? ""))
                                .font(.system(size: 12)).foregroundStyle(t.link).lineLimit(2)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Último paso, en el iPod", "Last step, on the iPod")).font(.system(size: 14, weight: .bold))
                        Text(L("Expulsa y actualiza la base de datos de Rockbox para que aparezcan las canciones nuevas.", "Eject, then update the Rockbox database so the new songs show up."))
                            .font(.system(size: 13)).foregroundStyle(t.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                RockboxMenuMock()
            }
            .padding(.horizontal, 44)
            .frame(maxHeight: .infinity)
            Footer(note: L("Configuración › Configuración general › Base de datos › Actualizar ahora", "Settings › General Settings › Database › Update Now")) {
                GhostButton(title: L("Cerrar", "Close")) { m.backHome(); close() }
                PrimaryButton(title: L("Expulsar iPod", "Eject iPod")) { m.eject { close() } }
            }
        }
    }
}

struct RockboxMenuMock: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let t = m.theme
        let items = isSpanish ? ["Cargar en RAM", "Inicializar ahora", "Actualizar ahora", "Actualización automática", "Recopilar estadísticas"]
                              : ["Load to RAM", "Initialize Now", "Update Now", "Auto Update", "Gather Runtime Data"]
        VStack(spacing: 0) {
            HStack {
                Text(L("General › Base de datos", "General › Database"))
                Spacer()
                Image(systemName: "battery.75percent")
            }
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(t.muted)
            .padding(.horizontal, 10).frame(height: 24)
            .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }
            ForEach(items, id: \.self) { it in
                let sel = it == items[2]
                Text(it)
                    .font(.system(size: 13, weight: sel ? .bold : .regular))
                    .foregroundStyle(sel ? t.selText : t.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).frame(height: 30)
                    .background(sel ? AnyShapeStyle(t.selector) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, sel ? 4 : 0)
            }
        }
        .padding(.bottom, 4)
        .frame(width: 300)
        .background(t.isLight ? Color.white : t.bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(6)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
    }
}
