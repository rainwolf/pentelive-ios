import UIKit

enum DBCrown: Equatable {
    case none, gold, silver, bronze
    case koth(index: Int)

    static func from(code: Int) -> DBCrown {
        switch code {
        case 1: return .gold
        case 2: return .silver
        case 3: return .bronze
        case 4 ... 39: return .koth(index: code - 4)
        default: return .none
        }
    }

    var imageName: String? {
        switch self {
        case .none: return nil
        case .gold: return "crown.gif"
        case .silver: return "scrown.gif"
        case .bronze: return "bcrown.gif"
        case let .koth(index): return "kothcrown\(index + 1)"
        }
    }
}

extension DBPlayer {
    init(name: String = "", rating: Int = 0, nameColor: Int = 0, crown: Int = 0) {
        self.name = name
        self.rating = rating
        self.nameColor = nameColor
        self.crown = crown
    }
}

enum DBRatingStyle {
    static func ratingHex(_ rating: Int) -> UInt32 {
        if rating >= 1900 { return 0xFF0000 }
        if rating >= 1700 { return 0xFAF508 }
        if rating >= 1400 { return 0x0000FF }
        if rating >= 1000 { return 0x1E824C }
        return 0x888888
    }

    static func nameHex(_ raw: Int) -> UInt32? {
        if raw == 0 { return nil }
        if raw == (255 << 24) + 1 { return 0x000000 }
        return UInt32(truncatingIfNeeded: raw) & 0xFFFFFF
    }

    static func nameString(_ p: DBPlayer?, font: UIFont, alignRight: Bool) -> NSAttributedString {
        guard let p = p else {
            return NSAttributedString(string: "?", attributes: [.font: font, .foregroundColor: DBPalette.ink])
        }
        let text = NSMutableAttributedString()
        if let hex = nameHex(p.nameColor) {
            let bold = font.fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
            text.append(NSAttributedString(string: p.name, attributes: [.font: bold, .foregroundColor: UIColor(dbHex: hex)]))
        } else {
            text.append(NSAttributedString(string: p.name, attributes: [.font: font, .foregroundColor: DBPalette.ink]))
        }
        if let img = DBCrown.from(code: p.crown).imageName, let image = UIImage(named: img) {
            let attachment = NSTextAttachment()
            attachment.image = image
            let side = font.lineHeight * 2 / 3
            attachment.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            text.append(NSAttributedString(string: " ", attributes: [.font: font]))
            text.append(NSAttributedString(attachment: attachment))
        }
        if alignRight {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        }
        return text
    }

    static func ratingString(_ p: DBPlayer?, font: UIFont) -> NSAttributedString {
        guard let p = p else { return NSAttributedString(string: "") }
        let s = NSMutableAttributedString(string: "\u{25A0} \(p.rating)",
                                          attributes: [.font: font, .foregroundColor: DBPalette.ink])
        s.addAttribute(.foregroundColor, value: UIColor(dbHex: ratingHex(p.rating)), range: NSRange(location: 0, length: 1))
        return s
    }
}
