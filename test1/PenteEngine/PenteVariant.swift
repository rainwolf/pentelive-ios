import Foundation

/// Game variants. Raw values are FROZEN to match the legacy ObjC
/// `PenteGameVariant` NS_ENUM in PenteGame.h so existing integer game codes and
/// the golden corpus continue to map correctly.
@objc enum PenteVariant: Int {
    case pente = 0
    case keryoPente = 1
    case gpente = 2
    case dPente = 3
    case dkPente = 4
    case oPente = 5
    case poofPente = 6
    case swap2Pente = 7
    case swap2Keryo = 8
    case gomoku = 9
    case connect6 = 10
}
