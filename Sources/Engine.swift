import Foundation
import CryptoKit

// MARK: - Tipos de archivo

enum Category: Int, CaseIterable {
    case music, photos, videos, other
    var title: String {
        switch self {
        case .music: return L("Música", "Music")
        case .photos: return L("Fotos", "Photos")
        case .videos: return L("Videos", "Videos")
        case .other: return L("Otros", "Other")
        }
    }
    static let musicExt: Set<String> = ["mp3", "m4a", "aac", "flac", "ogg", "oga", "opus", "wav", "aif", "aiff", "wma", "ape", "mpc", "wv", "alac", "m4b", "mp2", "spx"]
    static let photoExt: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "tif", "tiff", "webp"]
    static let videoExt: Set<String> = ["mp4", "m4v", "mov", "avi", "mpg", "mpeg", "mkv", "wmv", "3gp"]
    static func of(_ url: URL) -> Category {
        let e = url.pathExtension.lowercased()
        if musicExt.contains(e) { return .music }
        if photoExt.contains(e) { return .photos }
        if videoExt.contains(e) { return .videos }
        return .other
    }
}

struct FileEntry: Hashable {
    let url: URL
    let size: Int64
    let mtime: Double
    var path: String { url.path }
}

struct DeviceInfo {
    var name: String
    var url: URL
    var total: Int64
    var free: Int64
    var rockboxVersion: String
    var model: String
    var counts: [Category: Int] = [:]
    var bytes: [Category: Int64] = [:]
    var used: Int64 { total - free }
}

// MARK: - Escaneo

enum Scanner {
    /// Carpetas del iPod que nunca se tocan ni se cuentan como música del usuario.
    static let skipDirs: Set<String> = ["System Volume Information", "LOST.DIR", "Android", "Recordings"]

    static func files(under root: URL, onlyMusic: Bool) -> [FileEntry] {
        var out: [FileEntry] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                      options: [.skipsPackageDescendants]) else { return out }
        for case let url as URL in en {
            // Se saltan archivos/carpetas que empiezan con "." (.rockbox, ._AppleDouble, .DS_Store),
            // pero NO las marcadas como ocultas en FAT (iPod_Control lo está).
            if url.lastPathComponent.hasPrefix(".") {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { en.skipDescendants() }
                continue
            }
            guard let v = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if v.isDirectory == true {
                if skipDirs.contains(url.lastPathComponent) { en.skipDescendants() }
                continue
            }
            guard v.isRegularFile == true else { continue }
            if onlyMusic && Category.of(url) != .music { continue }
            out.append(FileEntry(url: url, size: Int64(v.fileSize ?? 0),
                                 mtime: v.contentModificationDate?.timeIntervalSince1970 ?? 0))
        }
        return out
    }

    static func deviceInfo(at vol: URL) -> DeviceInfo {
        let rv = try? vol.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeNameKey])
        var info = DeviceInfo(name: rv?.volumeName ?? vol.lastPathComponent, url: vol,
                              total: Int64(rv?.volumeTotalCapacity ?? 0),
                              free: Int64(rv?.volumeAvailableCapacity ?? 0),
                              rockboxVersion: "", model: "iPod")
        if let txt = try? String(contentsOf: vol.appendingPathComponent(".rockbox/rockbox-info.txt"), encoding: .utf8) {
            for line in txt.split(separator: "\n") {
                if line.hasPrefix("Version:") { info.rockboxVersion = line.dropFirst(8).trimmingCharacters(in: .whitespaces) }
                if line.hasPrefix("Target:") {
                    let t = line.dropFirst(7).trimmingCharacters(in: .whitespaces)
                    info.model = t == "ipod6g" ? "iPod classic" : t
                }
            }
        }
        var counts: [Category: Int] = [:], bytes: [Category: Int64] = [:]
        for f in files(under: vol, onlyMusic: false) {
            let c = Category.of(f.url)
            if c == .other { continue }
            counts[c, default: 0] += 1
            bytes[c, default: 0] += f.size
        }
        let known = (bytes[.music] ?? 0) + (bytes[.photos] ?? 0) + (bytes[.videos] ?? 0)
        bytes[.other] = max(0, info.used - known)
        counts[.other] = 0
        info.counts = counts
        info.bytes = bytes
        return info
    }

    static func isRockbox(_ vol: URL) -> Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: vol.appendingPathComponent(".rockbox").path, isDirectory: &dir) && dir.boolValue
    }
}

// MARK: - Índice de huellas (SHA-256)

struct HashRecord: Codable {
    var size: Int64
    var mtime: Double
    var quick: String?
    var full: String?
}

final class HashIndex {
    private(set) var records: [String: HashRecord] = [:]
    let file: URL
    private var dirty = false

    static var supportDir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RockSync", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    init(name: String) {
        let safe = name.replacingOccurrences(of: "/", with: "_")
        file = HashIndex.supportDir.appendingPathComponent("index-\(safe).json")
        if let d = try? Data(contentsOf: file), let r = try? JSONDecoder().decode([String: HashRecord].self, from: d) {
            records = r
        }
    }

    func save() {
        guard dirty else { return }
        if let d = try? JSONEncoder().encode(records) { try? d.write(to: file, options: .atomic) }
        dirty = false
    }

    private func record(for f: FileEntry) -> HashRecord {
        if let r = records[f.path], r.size == f.size, abs(r.mtime - f.mtime) < 2 { return r }
        return HashRecord(size: f.size, mtime: f.mtime, quick: nil, full: nil)
    }

    /// Huella rápida: tamaño + primeros y últimos 256 KB. Sólo sirve para descartar.
    func quick(_ f: FileEntry) -> String? {
        var r = record(for: f)
        if let q = r.quick { return q }
        guard let h = try? FileHandle(forReadingFrom: f.url) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        hasher.update(data: Data("\(f.size)".utf8))
        let chunk = 256 * 1024
        if let a = try? h.read(upToCount: chunk) { hasher.update(data: a) }
        if f.size > Int64(chunk * 2) {
            try? h.seek(toOffset: UInt64(f.size) - UInt64(chunk))
            if let b = try? h.read(upToCount: chunk) { hasher.update(data: b) }
        }
        let q = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        r.quick = q
        records[f.path] = r; dirty = true
        return q
    }

    /// Huella completa del contenido (SHA-256 de todo el archivo).
    func full(_ f: FileEntry, progress: ((Int64) -> Void)? = nil) -> String? {
        var r = record(for: f)
        if let x = r.full { progress?(f.size); return x }
        guard let x = HashIndex.sha256(of: f.url, progress: progress) else { return nil }
        r.full = x
        records[f.path] = r; dirty = true
        return x
    }

    func set(_ f: FileEntry, full: String) {
        var r = record(for: f)
        r.full = full
        records[f.path] = r; dirty = true
    }

    func forget(_ path: String) { records[path] = nil; dirty = true }

    static func sha256(of url: URL, progress: ((Int64) -> Void)? = nil) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        while true {
            guard let d = try? h.read(upToCount: 1 << 20), !d.isEmpty else { break }
            hasher.update(data: d)
            progress?(Int64(d.count))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Agrupar por contenido

enum Dupes {
    /// Devuelve grupos de archivos con contenido idéntico (2 o más por grupo).
    /// Compara por tamaño → huella rápida → huella completa, para leer lo mínimo.
    static func groups(_ files: [FileEntry], index: HashIndex,
                       progress: @escaping (Double, String) -> Void,
                       cancelled: () -> Bool) -> [[FileEntry]] {
        let bySize = Dictionary(grouping: files, by: \.size).values.filter { $0.count > 1 }
        var candidates: [[FileEntry]] = []
        let quickTotal = bySize.reduce(0) { $0 + $1.count }
        var done = 0
        for g in bySize {
            if cancelled() { return [] }
            var byQuick: [String: [FileEntry]] = [:]
            for f in g {
                if let q = index.quick(f) { byQuick[q, default: []].append(f) }
                done += 1
                progress(Double(done) / Double(max(quickTotal, 1)) * 0.15, f.url.lastPathComponent)
            }
            candidates += byQuick.values.filter { $0.count > 1 }
        }
        let totalBytes = candidates.reduce(Int64(0)) { $0 + $1.reduce(0) { $0 + $1.size } }
        var readBytes: Int64 = 0
        var result: [[FileEntry]] = []
        for g in candidates {
            if cancelled() { return [] }
            var byFull: [String: [FileEntry]] = [:]
            for f in g {
                let name = f.url.lastPathComponent
                if let x = index.full(f, progress: { n in
                    readBytes += n
                    progress(0.15 + 0.85 * Double(readBytes) / Double(max(totalBytes, 1)), name)
                }) { byFull[x, default: []].append(f) }
            }
            result += byFull.values.filter { $0.count > 1 }
        }
        index.save()
        return result
    }

    /// Nombre con sufijo de copia: "cancion (1)", "cancion copia", "cancion copy 2".
    static func looksLikeCopy(_ url: URL) -> Bool {
        let n = url.deletingPathExtension().lastPathComponent
        return n.range(of: #"(\s\(\d+\)|\s(copy|copia)(\s\d+)?)$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// The copy that is kept: outside the old iTunes folder (iPod_Control), without a "(1)" suffix, shortest path.
    static func keeper(of group: [FileEntry], volume: URL?) -> FileEntry {
        func score(_ f: FileEntry) -> (Int, Int, Int) {
            var inOld = 0
            if let v = volume { inOld = f.path.hasPrefix(v.appendingPathComponent("iPod_Control").path + "/") ? 1 : 0 }
            return (inOld, looksLikeCopy(f.url) ? 1 : 0, f.path.count)
        }
        return group.min { score($0) < score($1) }!
    }
}

// MARK: - Registro de lo que se quitó

struct RemovedItem: Codable, Identifiable {
    var id: String { removed + "\(date.timeIntervalSince1970)" }
    let removed: String
    let kept: String
    let size: Int64
    let date: Date
}

enum RemovedLog {
    static var file: URL { HashIndex.supportDir.appendingPathComponent("removed-duplicates.json") }
    static func load() -> [RemovedItem] {
        guard let d = try? Data(contentsOf: file) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode([RemovedItem].self, from: d)) ?? []
    }
    static func append(_ items: [RemovedItem]) {
        guard !items.isEmpty else { return }
        let all = load() + items
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        if let d = try? enc.encode(all) { try? d.write(to: file, options: .atomic) }
    }
}

// MARK: - Plan de sincronización

struct SyncItem: Identifiable {
    var id: String { source.path }
    let source: FileEntry
    let relative: String
}

struct SyncPlan {
    var items: [SyncItem] = []
    var alreadyOnIPod = 0
    var macDuplicates = 0
    var bytes: Int64 { items.reduce(0) { $0 + $1.source.size } }
    var free: Int64 = 0
    var fits: Bool { bytes + 50_000_000 < free }
}

enum Planner {
    static func plan(macRoot: URL, macFiles: [FileEntry], ipodFiles: [FileEntry],
                     macIndex: HashIndex, ipodIndex: HashIndex, free: Int64,
                     progress: @escaping (Double, String) -> Void,
                     cancelled: () -> Bool) -> SyncPlan {
        var plan = SyncPlan(free: free)
        let ipodBySize = Dictionary(grouping: ipodFiles, by: \.size)
        var fresh: [FileEntry] = []
        let total = Double(max(macFiles.count, 1))
        for (i, m) in macFiles.enumerated() {
            if cancelled() { return SyncPlan() }
            progress(Double(i) / total * 0.9, m.url.lastPathComponent)
            guard let same = ipodBySize[m.size], let mq = macIndex.quick(m) else { fresh.append(m); continue }
            let quickMatches = same.filter { ipodIndex.quick($0) == mq }
            if quickMatches.isEmpty { fresh.append(m); continue }
            let mf = macIndex.full(m)
            if mf != nil && quickMatches.contains(where: { ipodIndex.full($0) == mf }) {
                plan.alreadyOnIPod += 1
            } else {
                fresh.append(m)
            }
        }
        // Canciones repetidas dentro de la Mac: sólo se copia una.
        let groups = Dupes.groups(fresh, index: macIndex, progress: { p, n in progress(0.9 + p * 0.1, n) }, cancelled: cancelled)
        var skip = Set<String>()
        for g in groups {
            let keep = Dupes.keeper(of: g, volume: nil)
            for f in g where f.path != keep.path { skip.insert(f.path) }
        }
        plan.macDuplicates = skip.count
        let rootPath = macRoot.standardizedFileURL.path
        for f in fresh where !skip.contains(f.path) {
            var rel = f.url.standardizedFileURL.path
            if rel.hasPrefix(rootPath) { rel = String(rel.dropFirst(rootPath.count)) }
            while rel.hasPrefix("/") { rel.removeFirst() }
            plan.items.append(SyncItem(source: f, relative: rel))
        }
        plan.items.sort { $0.relative.localizedStandardCompare($1.relative) == .orderedAscending }
        macIndex.save(); ipodIndex.save()
        return plan
    }
}

// MARK: - Copia

enum Copier {
    enum CopyError: LocalizedError {
        case verify(String), io(String)
        var errorDescription: String? {
            switch self {
            case .verify(let n): return L("La copia de “\(n)” no coincide con el original. Se descartó.", "The copy of “\(n)” didn't match the original and was discarded.")
            case .io(let m): return m
            }
        }
    }

    static func uniqueDestination(_ url: URL) -> URL {
        var dst = url
        var n = 2
        while FileManager.default.fileExists(atPath: dst.path) {
            let base = url.deletingPathExtension().lastPathComponent
            dst = url.deletingLastPathComponent().appendingPathComponent("\(base) (\(n))").appendingPathExtension(url.pathExtension)
            n += 1
        }
        return dst
    }

    /// Copia sólo los datos (sin crear archivos "._" en el iPod) y verifica con SHA-256.
    static func copy(_ src: URL, to dst: URL, chunk: (Int64) -> Void, cancelled: () -> Bool) throws -> String {
        try FileManager.default.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: dst.path, contents: nil),
              let out = try? FileHandle(forWritingTo: dst),
              let inp = try? FileHandle(forReadingFrom: src) else {
            throw CopyError.io(L("No pude crear “\(dst.lastPathComponent)” en el iPod.", "Couldn't create “\(dst.lastPathComponent)” on the iPod."))
        }
        var hasher = SHA256()
        do {
            defer { try? inp.close() }
            while true {
                if cancelled() { try? out.close(); try? FileManager.default.removeItem(at: dst); throw CancellationError() }
                guard let d = try inp.read(upToCount: 1 << 20), !d.isEmpty else { break }
                hasher.update(data: d)
                try out.write(contentsOf: d)
                chunk(Int64(d.count))
            }
            try out.synchronize()
            try out.close()
        } catch let e as CancellationError {
            throw e
        } catch {
            try? out.close()
            try? FileManager.default.removeItem(at: dst)
            throw CopyError.io(L("Error al copiar “\(src.lastPathComponent)”: ", "Error copying “\(src.lastPathComponent)”: ") + error.localizedDescription)
        }
        let want = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let got = HashIndex.sha256(of: dst)
        if got != want {
            try? FileManager.default.removeItem(at: dst)
            throw CopyError.verify(src.lastPathComponent)
        }
        return want
    }
}

/// Spanish if the Mac's preferred language is Spanish, English otherwise.
let isSpanish = (ProcessInfo.processInfo.environment["RS_LANG"] ?? Locale.preferredLanguages.first ?? "en").hasPrefix("es")
func L(_ es: String, _ en: String) -> String { isSpanish ? es : en }

/// Folder on the iPod where new songs go: an existing "Music"/"Musica"/"Música" folder, or "Music".
func destinationFolder(on vol: URL) -> URL {
    for n in ["Music", "Musica", "Música", "MUSIC", "music"] {
        var d: ObjCBool = false
        let u = vol.appendingPathComponent(n, isDirectory: true)
        if FileManager.default.fileExists(atPath: u.path, isDirectory: &d), d.boolValue { return u }
    }
    return vol.appendingPathComponent("Music", isDirectory: true)
}

func formatBytes(_ b: Int64) -> String {
    if b <= 0 { return "0 GB" }
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowedUnits = b >= 1_000_000_000 ? [.useGB] : [.useMB, .useKB]
    return f.string(fromByteCount: b)
}
