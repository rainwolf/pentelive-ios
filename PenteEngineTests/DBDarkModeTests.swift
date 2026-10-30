@testable import penteLive
import XCTest

/// Never reached: the filters sheet makes no request while it is built.
private struct DBDarkModeTransport: Transport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        XCTFail("no request expected: \(request.url?.absoluteString ?? "")")
        throw URLError(.cancelled)
    }
}

/// PenteDB chrome must stay legible in both appearances. The filters sheet
/// once drew near-black ink (a fixed light-mode hex) on the dark system
/// background, so every label vanished.
@MainActor
final class DBDarkModeTests: XCTestCase {
    private static let dark = UITraitCollection(userInterfaceStyle: .dark)
    private static let light = UITraitCollection(userInterfaceStyle: .light)
    /// WCAG AA for normal text.
    private static let minContrast: CGFloat = 4.5

    // MARK: helpers

    private static func luminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    static func contrast(_ a: UIColor, _ b: UIColor, in traits: UITraitCollection) -> CGFloat {
        let la = luminance(a.resolvedColor(with: traits)), lb = luminance(b.resolvedColor(with: traits))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Plain labels only: a control's title label takes the control's own
    /// colour (tint or title colour), which is checked separately.
    private func labels(in view: UIView) -> [UILabel] {
        if view is UIControl { return [] }
        var out: [UILabel] = []
        if let l = view as? UILabel { out.append(l) }
        for s in view.subviews { out += labels(in: s) }
        return out
    }

    private func makeFilters(style: UIUserInterfaceStyle) -> DBFiltersViewController {
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false), transport: DBDarkModeTransport())
        let vc = DBFiltersViewController(applied: DBFilterState(),
                                         autocomplete: DBPlayerAutocomplete(client: client, debounce: 0),
                                         features: DBServerFeatures(excludeTimeouts: true, liveOrTurnBased: true))
        vc.overrideUserInterfaceStyle = style
        vc.loadViewIfNeeded()
        return vc
    }

    // MARK: filters sheet

    private func assertFiltersLegible(style: UIUserInterfaceStyle, _ traits: UITraitCollection,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let vc = makeFilters(style: style)
        let background = vc.view.backgroundColor ?? .clear
        let shown = labels(in: vc.view).filter { !($0.text ?? "").isEmpty }
        let texts = Set(shown.compactMap(\.text))
        for expected in ["Filters", "Speed", "P1 min rating", "P2 min rating", "Either seat",
                         "Exclude timeouts", "Games", "Winner", "After", "Before", "Source"] {
            XCTAssertTrue(texts.contains(expected), "missing row label \(expected): \(texts)", file: file, line: line)
        }
        for l in shown {
            let c = Self.contrast(l.textColor, background, in: traits)
            XCTAssertGreaterThanOrEqual(c, Self.minContrast,
                                        "\"\(l.text ?? "")\" contrast \(c) on the \(style.rawValue) background",
                                        file: file, line: line)
        }
        for chip in vc.gameChips {
            let selected = chip.isSelected
            let title = chip.titleColor(for: selected ? .selected : .normal) ?? .clear
            let fill = selected ? (chip.backgroundColor ?? background) : background
            let c = Self.contrast(title, fill, in: traits)
            XCTAssertGreaterThanOrEqual(c, Self.minContrast,
                                        "chip \(chip.title(for: .normal) ?? "") contrast \(c) (selected \(selected))",
                                        file: file, line: line)
        }
        // Unselected chips are the common case; make sure the check saw some.
        XCTAssertGreaterThan(vc.gameChips.filter { !$0.isSelected }.count, 5, file: file, line: line)
    }

    func testFiltersSheetTextIsLegibleInDarkMode() {
        assertFiltersLegible(style: .dark, Self.dark)
    }

    func testFiltersSheetTextIsLegibleInLightMode() {
        assertFiltersLegible(style: .light, Self.light)
    }

    func testFiltersSheetFollowsItsInterfaceStyleOverride() {
        let vc = makeFilters(style: .dark)
        XCTAssertEqual(vc.overrideUserInterfaceStyle, .dark)
        let title = labels(in: vc.view).first { $0.text == "Filters" }
        XCTAssertNotNil(title)
        // The resolved ink really differs between the two appearances.
        let inkDark = title!.textColor.resolvedColor(with: Self.dark)
        let inkLight = title!.textColor.resolvedColor(with: Self.light)
        XCTAssertNotEqual(inkDark.dbHexString, inkLight.dbHexString)
    }

    func testSelectedChipBorderFollowsAppearance() {
        let vc = makeFilters(style: .dark)
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        let chip = vc.gameChips.first { !$0.isSelected }!
        let resolved = DBPalette.chipOutline.resolvedColor(with: vc.traitCollection)
        XCTAssertEqual(UIColor(cgColor: chip.layer.borderColor!).dbHexString, resolved.dbHexString)
    }

    // MARK: palette

    func testPaletteTextColoursAreLegibleOnTheSystemBackgroundInBothAppearances() {
        for (name, colour) in [("ink", DBPalette.ink), ("secondaryText", DBPalette.secondaryText),
                               ("secondaryText2", DBPalette.secondaryText2), ("accent", DBPalette.accent)] {
            for traits in [Self.light, Self.dark] {
                let c = Self.contrast(colour, .systemBackground, in: traits)
                XCTAssertGreaterThanOrEqual(c, Self.minContrast, "\(name) \(traits.userInterfaceStyle.rawValue): \(c)")
            }
        }
    }

    func testAccentIsLegibleOnTheSelectedChipFillInBothAppearances() {
        for traits in [Self.light, Self.dark] {
            let c = Self.contrast(DBPalette.accent, DBPalette.chipSelectedFill, in: traits)
            XCTAssertGreaterThanOrEqual(c, Self.minContrast, "\(traits.userInterfaceStyle.rawValue): \(c)")
        }
    }

    // MARK: results rows

    func testMoveAndGameRowTextIsLegibleInDarkMode() {
        let moveCell = DBMoveRowCell(style: .default, reuseIdentifier: nil)
        moveCell.configure(DBMoveRow(cell: 180, label: "K10", pctText: "58%", barFraction: 0.58,
                                     gamesText: "1,234", color: .green), marked: true)
        for l in [moveCell.moveLabel, moveCell.pctLabel, moveCell.gamesLabel] {
            for marked in [true, false] {
                moveCell.setMarked(marked)
                let bg = marked ? DBPalette.chipSelectedFill : UIColor.systemBackground
                let c = Self.contrast(l.textColor, bg, in: Self.dark)
                XCTAssertGreaterThanOrEqual(c, Self.minContrast, "\(l.text ?? "") marked \(marked): \(c)")
            }
        }
    }

    func testViewerMoveCellTextIsLegibleInDarkMode() {
        let cell = DBMoveGridCell(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        for state in [DBMoveCellState.past, .current] {
            cell.configure(DBMoveCell(index: 0, number: "1", label: "K10", state: state))
            let bg = cell.contentView.backgroundColor.flatMap { $0 == .clear ? nil : $0 } ?? .systemBackground
            let c = Self.contrast(cell.label.textColor, bg, in: Self.dark)
            XCTAssertGreaterThanOrEqual(c, Self.minContrast, "\(state): \(c)")
        }
        let number = Self.contrast(cell.numberLabel.textColor, .systemBackground, in: Self.dark)
        XCTAssertGreaterThanOrEqual(number, Self.minContrast)
    }

    // MARK: screenshots for the controller (not assertions)

    private func writePNG(_ view: UIView, style: UIUserInterfaceStyle, name: String) {
        let size = view.bounds.size
        let traits = UITraitCollection(userInterfaceStyle: style)
        let renderer = UIGraphicsImageRenderer(size: size)
        var image: UIImage!
        traits.performAsCurrent {
            image = renderer.image { ctx in
                (view.backgroundColor ?? .systemBackground).resolvedColor(with: traits).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                view.layer.render(in: ctx.cgContext)
            }
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let path = ProcessInfo.processInfo.environment["DB_SCREENSHOT_DIR"], !path.isEmpty {
            let dir = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? image.pngData()?.write(to: dir.appendingPathComponent(name))
        }
    }

    func testWritesDarkFiltersScreenshot() {
        let vc = makeFilters(style: .dark)
        vc.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        writePNG(vc.view, style: .dark, name: "filters-dark.png")
    }
}
