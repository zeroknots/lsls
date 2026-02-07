import SwiftUI

extension ThemeColor {
    var color: Color {
        let hex = self.hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r, g, b, a: Double

        switch hex.count {
        case 6:
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((rgb >> 24) & 0xFF) / 255
            g = Double((rgb >> 16) & 0xFF) / 255
            b = Double((rgb >> 8) & 0xFF) / 255
            a = Double(rgb & 0xFF) / 255
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1.0
        }

        let base = Color(.sRGB, red: r, green: g, blue: b, opacity: a)

        if let opacity {
            return base.opacity(opacity)
        }
        return base
    }
}
