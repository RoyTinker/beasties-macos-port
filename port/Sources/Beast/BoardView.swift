import AppKit
import BeastCore

/// The game window's content. Drawing is [DRAWMATR] and [DRAWCLOC]; input is the non-menu
/// part of [DOKEYDOW] and [DOMOUSED].
final class BoardView: NSView {
    private let game: BeastGame
    /// Called after every key or click, so the app can run beeps and alerts.
    var afterInput: () -> Void = {}

    /// gPics, indexed by cell value. PICT 200, 201 and 202.
    private let sprites: [Cell: NSImage] = [
        .man: PICTImage(Artwork.man).image,
        .block: PICTImage(Artwork.block).image,
        .beast: PICTImage(Artwork.beast).image,
    ]

    /// [SETUPWIN] sets TextSize(9) and TextFace([bold]) on the system font, Chicago.
    private let clockFont = NSFont.boldSystemFont(ofSize: 9)

    init(game: BeastGame, frame: NSRect) {
        self.game = game
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        drawMatrix(dirtyRect)
        drawClock()
    }

    /// [DRAWMATR] Empty cells aren't drawn: the background is already erased.
    private func drawMatrix(_ dirtyRect: NSRect) {
        let size = BeastGame.cellSize
        for y in 1...BeastGame.rows {
            for x in 1...BeastGame.columns {
                let cell = game.cell(x, y)
                guard cell != .empty, let sprite = sprites[cell] else { continue }
                let r = NSRect(x: (x - 1) * size, y: (y - 1) * size, width: size, height: size)
                guard r.intersects(dirtyRect) else { continue }
                sprite.draw(in: r, from: .zero, operation: .copy, fraction: 1,
                            respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            }
        }
    }

    /// [DRAWCLOC] "Time: n" in a framed box at (420, 283)-(485, 295). The box overlaps the
    /// bottom wall row, as in the original.
    private func drawClock() {
        let box = NSRect(x: 420, y: 283, width: 65, height: 12)
        NSColor.white.setFill()
        box.fill()
        let text = NSAttributedString(string: "Time: \(game.clock)",
                                      attributes: [.font: clockFont, .foregroundColor: NSColor.black])
        // MoveTo(422, 293) puts the baseline at y = 293.
        text.draw(at: NSPoint(x: 422, y: 293 - clockFont.ascender))
        NSColor.black.setStroke()
        NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }

    // MARK: - Input

    override func keyDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.command) else { return super.keyDown(with: event) }
        // The original used the character code, so shifted and unshifted keys both work.
        // Keys with no single-byte character (arrows, function keys) beep, as other keys did.
        let scalar = event.characters?.unicodeScalars.first?.value ?? 0xFF
        game.keyDown(charCode: scalar < 0x100 ? Int(scalar) : 0xFF)
        afterInput()
    }

    override func mouseDown(with event: NSEvent) {
        game.contentClick()
        afterInput()
    }

    // MARK: - Edit menu

    // The original's Edit menu was only for desk accessories. Used on the game window it
    // showed this alert, so the port does the same.
    @objc func undo(_ sender: Any?) { editCommand() }
    @objc func cut(_ sender: Any?) { editCommand() }
    @objc func copy(_ sender: Any?) { editCommand() }
    @objc func paste(_ sender: Any?) { editCommand() }
    @objc func delete(_ sender: Any?) { editCommand() }

    private func editCommand() {
        Dialogs.error("Edit commands are currently for DAs only.")
    }
}
