import UIKit

/// Board colours per spec section 3.1, plus chrome colours.
@objc final class DBPalette: NSObject {
    private static let penteHex: UInt32 = 0xFDDEA3
    private static let boards: [Int: UInt32] = [
        1: 0xFDDEA3, 3: 0xBAFDA3, 5: 0xA3FDEB, 7: 0xA3CDFD, 9: 0xAEA3FD,
        11: 0xEDA3FD, 13: 0xEDA3FD, 15: 0x25BAFF, 17: 0xFFA500, 25: 0x52BE80,
        27: 0xE5AA70, 29: 0x50C878,
    ]

    @objc static func boardColor(forGame id: Int) -> UIColor {
        return UIColor(dbHex: boardHex(forGame: id))
    }

    /// Unsupported ids give the Pente hex.
    static func boardHex(forGame id: Int) -> UInt32 {
        return boards[DBGameCatalog.baseGame(id)] ?? penteHex
    }

    static let ink = UIColor(dbHex: 0x16181D)
    static let secondaryText = UIColor(dbHex: 0x4A4F5A)
    static let secondaryText2 = UIColor(dbHex: 0x5C616B)
    static let accent = UIColor(dbHex: 0x1F5FD6)
    static let divider = UIColor(dbHex: 0xE2E4E9)
    static let chipOutline = UIColor(dbHex: 0xC8CCD4)
    static let chipSelectedFill = UIColor(dbHex: 0xE3ECFC)
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
