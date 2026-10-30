import UIKit

/// Board colours per spec section 3.1, plus chrome colours.
@objc final class DBPalette: NSObject {
    private static let penteHex: UInt32 = 0xFDDEA3
    private static let boards: [Int: UInt32] = [
        1: 0xFDDEA3, 3: 0xBAFDA3, 5: 0xA3FDEB, 7: 0xA3CDFD, 9: 0xAEA3FD,
        11: 0xEDA3FD, 13: 0xEDA3FD, 15: 0x25BAFF, 17: 0xFFA500, 25: 0x52BE80,
        27: 0xE5AA70, 29: 0x50C878,
        // Go and Renju: the web board.css and live-board colours.
        19: 0xFAC832, 21: 0xFAC832, 23: 0xFAC832, 31: 0xD98880,
    ]

    @objc static func boardColor(forGame id: Int) -> UIColor {
        return UIColor(dbHex: boardHex(forGame: id))
    }

    /// Unsupported ids give the Pente hex.
    static func boardHex(forGame id: Int) -> UInt32 {
        return boards[DBGameCatalog.baseGame(id)] ?? penteHex
    }

    /// Chrome colours follow the interface style: the light value is the
    /// original fixed hex, the dark one a light-on-dark counterpart. A fixed
    /// light ink drew near-black text on the dark background.
    private static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        let l = UIColor(dbHex: light), d = UIColor(dbHex: dark)
        return UIColor { $0.userInterfaceStyle == .dark ? d : l }
    }

    @objc static let ink = adaptive(light: 0x16181D, dark: 0xF2F3F5)
    static let secondaryText = adaptive(light: 0x4A4F5A, dark: 0xB8BCC6)
    static let secondaryText2 = adaptive(light: 0x5C616B, dark: 0xA9AEB9)
    @objc static let accent = adaptive(light: 0x1F5FD6, dark: 0x6EA2FF)
    static let divider = adaptive(light: 0xE2E4E9, dark: 0x3A3D44)
    @objc static let chipOutline = adaptive(light: 0xC8CCD4, dark: 0x4A4F5A)
    @objc static let chipSelectedFill = adaptive(light: 0xE3ECFC, dark: 0x1B2F52)
    static let futureMove = UIColor(dbHex: 0x8A8F99)
}

extension UIColor {
    convenience init(dbHex hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    var dbHexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int((r * 255).rounded()),
                      Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}
