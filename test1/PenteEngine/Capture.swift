import Foundation

/// A captured stone. Swift name `Capture`; exposed to Objective-C as
/// `PenteCapture` to avoid colliding with the legacy C `typedef struct … Capture`
/// in PenteGame.h (which survives until Phase 5).
@objc(PenteCapture) final class Capture: NSObject {
    @objc let position: Int   // rowCol = row * 19 + col
    @objc let color: Int      // colour of the captured stone (1 white, 2 black)
    @objc init(position: Int, color: Int) {
        self.position = position
        self.color = color
        super.init()
    }
}
