import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// Colores tomados de los themes de Rockbox del iPod (.rockbox/themes/*.cfg).
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let isLight: Bool
    let bg: Color
    let bar: Color
    let line: Color
    let fg: Color
    let muted: Color
    let a1: Color          // barra de selección (inicio)
    let a2: Color          // barra de selección (fin)
    let selText: Color
    let btn1: Color
    let btn2: Color
    let btnText: Color
    let soft: Color
    let link: Color
    let glow: Color?

    var selector: LinearGradient { LinearGradient(colors: [a1, a2], startPoint: .leading, endPoint: .trailing) }
    var button: LinearGradient { LinearGradient(colors: [btn1, btn2], startPoint: .leading, endPoint: .trailing) }

    static func == (l: Theme, r: Theme) -> Bool { l.id == r.id }

    static let basico = Theme(
        id: "basico", name: L("A · Básico", "A · Basic"), isLight: true,
        bg: Color(hex: 0xF5F5F7), bar: Color(hex: 0xFFFFFF), line: Color(hex: 0xE0E0E3),
        fg: Color(hex: 0x1D1D1F), muted: Color(hex: 0x6E6E73),
        a1: Color(hex: 0x0A7AFF), a2: Color(hex: 0x0071E3), selText: .white,
        btn1: Color(hex: 0x0071E3), btn2: Color(hex: 0x0071E3), btnText: .white,
        soft: Color(hex: 0x0071E3, alpha: 0.08), link: Color(hex: 0x0066CC), glow: nil)

    static let pulsoRosa = Theme(
        id: "pulso-rosa", name: "B · Pulso Rosa", isLight: false,
        bg: Color(hex: 0x111114), bar: Color(hex: 0x18181C), line: Color(hex: 0x2C2C33),
        fg: Color(hex: 0xF2F2F5), muted: Color(hex: 0xA3A3AD),
        a1: Color(hex: 0xFF3385), a2: Color(hex: 0xE81E6C), selText: .white,
        btn1: Color(hex: 0xF0287A), btn2: Color(hex: 0xC8105A), btnText: .white,
        soft: Color(hex: 0xFF3385, alpha: 0.12), link: Color(hex: 0xFF5C9D), glow: nil)

    static let pulsoTiffany = Theme(
        id: "pulso-tiffany", name: "C · Pulso Tiffany", isLight: false,
        bg: Color(hex: 0x111114), bar: Color(hex: 0x18181C), line: Color(hex: 0x2C2C33),
        fg: Color(hex: 0xF2F2F5), muted: Color(hex: 0xA3A3AD),
        a1: Color(hex: 0x2ED2CB), a2: Color(hex: 0x0AB2AD), selText: Color(hex: 0x042221),
        btn1: Color(hex: 0x2ED2CB), btn2: Color(hex: 0x0AB2AD), btnText: Color(hex: 0x042221),
        soft: Color(hex: 0x2ED2CB, alpha: 0.12), link: Color(hex: 0x4FE0D9), glow: nil)

    static let balmo = Theme(
        id: "balmo-music", name: "D · Balmo Music", isLight: false,
        bg: Color(hex: 0x3D3C44), bar: Color(hex: 0x35343B), line: Color(hex: 0x55545D),
        fg: Color(hex: 0xF5F5F7), muted: Color(hex: 0xC9C8D0),
        a1: Color(hex: 0xFA3158), a2: Color(hex: 0xFA3158), selText: .white,
        btn1: Color(hex: 0xE3264B), btn2: Color(hex: 0xE3264B), btnText: .white,
        soft: Color(hex: 0xFA3158, alpha: 0.18), link: Color(hex: 0xFF9AAE), glow: nil)

    static let neon = Theme(
        id: "neon", name: "E · Neon", isLight: false,
        bg: Color(hex: 0x241A1E), bar: Color(hex: 0x1D1518), line: Color(hex: 0x3D2C34),
        fg: Color(hex: 0xFFF4FA), muted: Color(hex: 0xBF95B0),
        a1: Color(hex: 0x7A2A5F), a2: Color(hex: 0x5A1E46), selText: Color(hex: 0xFFF4FA),
        btn1: Color(hex: 0x8A3070), btn2: Color(hex: 0x5A1E46), btnText: Color(hex: 0xFFF4FA),
        soft: Color(hex: 0xD66AA8, alpha: 0.14), link: Color(hex: 0xEC9FCB),
        glow: Color(hex: 0xEC78BE, alpha: 0.65))

    static let all: [Theme] = [basico, pulsoRosa, pulsoTiffany, balmo, neon]
    static func with(id: String) -> Theme { all.first { $0.id == id } ?? basico }
}
