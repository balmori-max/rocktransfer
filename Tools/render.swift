import SwiftUI
import AppKit

// Renders the app icon, screenshots and the Reddit/GitHub artwork straight from the app's own views.
// Build: swiftc -parse-as-library Sources/{Engine,Model,Theme,Views}.swift Tools/render.swift -o build/render

struct WindowChrome<C: View>: View {
    let theme: Theme
    @ViewBuilder var content: C
    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: 0xFF5F57)); Circle().fill(Color(hex: 0xFEBC2E)); Circle().fill(Color(hex: 0x28C840))
                }.frame(width: 52, height: 12).padding(.leading, 16).padding(.top, 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(theme.isLight ? 0 : 0.12), lineWidth: 1))
    }
}

struct AppIcon: View {
    var body: some View {
        let t = Theme.pulsoRosa
        ZStack {
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2A2A30), Color(hex: 0x0E0E11)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
            // iPod body
            ZStack {
                RoundedRectangle(cornerRadius: 64, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xF4F4F6), Color(hex: 0xC4C4CA)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 14)
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(0..<4) { i in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(i == 1 ? AnyShapeStyle(t.selector) : AnyShapeStyle(Color.white.opacity(0.25)))
                                .frame(width: CGFloat([150, 250, 190, 120][i]), height: 28)
                        }
                    }
                    .padding(.leading, 28)
                    .frame(width: 316, height: 230, alignment: .leading)
                    .background(Color(hex: 0x111114), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 42)
                    Spacer()
                    ZStack {
                        Circle().fill(Color.white).overlay(Circle().stroke(Color(hex: 0xBDBDC3), lineWidth: 4))
                        Circle().fill(LinearGradient(colors: [Color(hex: 0xFF3385), Color(hex: 0xE81E6C)], startPoint: .top, endPoint: .bottom)).frame(width: 104, height: 104)
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 52, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 250, height: 250).padding(.bottom, 44)
                }
            }
            .frame(width: 400, height: 640)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func fake(_ m: AppModel, theme: Theme) {
    m.theme = theme
    var d = DeviceInfo(name: "MY IPOD", url: URL(fileURLWithPath: "/Volumes/MY IPOD"), total: 249_900_000_000, free: 238_400_000_000,
                       rockboxVersion: "4.0", model: "iPod classic")
    d.counts = [.music: 2_148, .photos: 36, .videos: 4, .other: 0]
    d.bytes = [.music: 9_720_000_000, .photos: 120_000_000, .videos: 1_100_000_000, .other: 560_000_000]
    m.device = d
    m.macSongCount = 2_193
    m.musicFolder = URL(fileURLWithPath: NSHomeDirectory() + "/Music")
}

@MainActor func save<V: View>(_ v: V, _ path: String, scale: CGFloat = 2) {
    let r = ImageRenderer(content: v)
    r.scale = scale
    guard let img = r.cgImage else { print("FAIL \(path)"); return }
    let rep = NSBitmapImageRep(cgImage: img)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    print("ok \(path) \(img.width)x\(img.height)")
}

@MainActor func window(_ m: AppModel, _ screen: Screen) -> some View {
    m.screen = screen
    return WindowChrome(theme: m.theme) { RootView(close: {}).environmentObject(m) }
}

@MainActor func plan(_ m: AppModel) {
    let names = ["Boards of Canada/Music Has the Right to Children/03 Roygbiv.flac", "Radiohead/In Rainbows/01 15 Step.mp3",
                 "Björk/Homogenic/02 Jóga.m4a", "Massive Attack/Mezzanine/01 Angel.mp3", "Aphex Twin/Selected Ambient Works/04 Xtal.flac",
                 "Portishead/Dummy/03 Sour Times.mp3", "Daft Punk/Discovery/01 One More Time.mp3", "Cocteau Twins/Heaven or Las Vegas/01 Cherry-coloured Funk.flac"]
    var p = SyncPlan(free: 238_400_000_000)
    for (i, n) in names.enumerated() {
        p.items.append(SyncItem(source: FileEntry(url: URL(fileURLWithPath: "/x/" + n), size: Int64(8_000_000 + i * 3_700_000), mtime: 0), relative: n))
    }
    p.alreadyOnIPod = 2_148; p.macDuplicates = 3
    m.plan = p
}

struct Hero: View {
    let front: AnyView
    let back: AnyView
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: 0x0E0E11)
            RadialGradient(colors: [Color(hex: 0xFF3385, alpha: 0.35), .clear], center: UnitPoint(x: 0.78, y: 0.55), startRadius: 0, endRadius: 620)
            RadialGradient(colors: [Color(hex: 0x2ED2CB, alpha: 0.18), .clear], center: UnitPoint(x: 1.0, y: 0.0), startRadius: 0, endRadius: 520)
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    AppIcon().frame(width: 1024, height: 1024).scaleEffect(64.0 / 1024).frame(width: 64, height: 64)
                    Text("RockTransfer").font(.system(size: 34, weight: .heavy)).foregroundStyle(.white)
                }
                Text("Sync music to your\nRockbox iPod.")
                    .font(.system(size: 62, weight: .heavy)).tracking(-1.5).foregroundStyle(.white).lineSpacing(-4)
                Text("No iTunes. No Music app. No duplicates.")
                    .font(.system(size: 24, weight: .medium)).foregroundStyle(Color(hex: 0xFF5C9D))
                VStack(alignment: .leading, spacing: 12) {
                    bullet("Copies only the songs that are new, matched by content")
                    bullet("Finds duplicate copies already on the iPod")
                    bullet("Opens by itself when you plug the iPod in")
                    bullet("5 themes based on Rockbox colors")
                }.padding(.top, 8)
                Spacer()
                Text("Free & open source · macOS 14+ · Apple silicon & Intel")
                    .font(.system(size: 16, design: .monospaced)).foregroundStyle(Color(hex: 0xA3A3AD))
            }
            .padding(.leading, 80).padding(.top, 84).padding(.bottom, 64)
            back.scaleEffect(0.62, anchor: .topLeading).offset(x: 920, y: 70).opacity(0.9)
                .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
            front.scaleEffect(0.78, anchor: .topLeading).offset(x: 760, y: 330)
                .shadow(color: .black.opacity(0.7), radius: 40, y: 20)
        }
        .frame(width: 1600, height: 900)
        .clipped()
    }
    func bullet(_ s: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(LinearGradient(colors: [Color(hex: 0xFF3385), Color(hex: 0xE81E6C)], startPoint: .top, endPoint: .bottom)).frame(width: 10, height: 10)
            Text(s).font(.system(size: 21)).foregroundStyle(Color(hex: 0xE6E6EA))
        }
    }
}

@main
enum Render {
    @MainActor static func main() {
        renderMode = true
        let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "art"
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        save(AppIcon(), out + "/icon-1024.png", scale: 1)

        // Screenshots: one model per image (views read the model when rendered)
        for t in Theme.all {
            let m = AppModel(); fake(m, theme: t); m.dedupe = .found(41, 412_000_000)
            save(window(m, .home), out + "/home-\(t.id).png")
        }
        let p = AppModel(); fake(p, theme: Theme.pulsoRosa); plan(p)
        save(window(p, .preview), out + "/preview.png")
        let d = AppModel(); fake(d, theme: Theme.pulsoTiffany); d.result = CopyResult(copied: 45, bytes: 492_800_000)
        save(window(d, .done), out + "/done.png")
        let w = AppModel(); w.theme = Theme.basico
        save(window(w, .waiting), out + "/waiting.png")

        // Hero image for Reddit / GitHub
        let f = AppModel(); fake(f, theme: Theme.pulsoRosa); f.dedupe = .found(41, 412_000_000)
        let b = AppModel(); fake(b, theme: Theme.pulsoTiffany); plan(b)
        let hero = Hero(front: AnyView(window(f, .home)), back: AnyView(window(b, .preview)))
        save(hero, out + "/hero.png")
    }
}
