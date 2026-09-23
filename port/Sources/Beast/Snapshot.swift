import AppKit
import BeastCore

/// `Beast --snapshot <dir>` writes PNGs of the game window and every dialog, then quits.
/// This is a developer aid for checking the drawing without clicking through the app.
enum Snapshot {
    static var directory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }

    static func write(board: NSView, game: BeastGame, to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        save(board, dir.appendingPathComponent("board-empty.png"))
        game.newGame(seed: 1989)
        save(board, dir.appendingPathComponent("board-newgame.png"))
        if let board = board as? BoardView {
            let scale = board.scale
            board.scale = 2
            save(board, dir.appendingPathComponent("board-newgame-2x.png"))
            board.scale = scale
        }
        save(Dialogs.aboutDialog().contentView, dir.appendingPathComponent("about.png"))
        save(Dialogs.helpDialog().contentView, dir.appendingPathComponent("help.png"))
        save(Dialogs.infoDialog().contentView, dir.appendingPathComponent("info.png"))
        save(Dialogs.settingsDialog(.defaults).contentView, dir.appendingPathComponent("settings.png"))
        save(Dialogs.errorDialog("Dead Meat !!!").contentView, dir.appendingPathComponent("error.png"))
    }

    private static func save(_ view: NSView, _ url: URL) {
        view.layoutSubtreeIfNeeded()
        // Render at the view's on-screen size on a 2x (Retina) display. The view's bounds
        // may be smaller than its frame when it is zoomed.
        let pixels = NSSize(width: view.frame.width * 2, height: view.frame.height * 2)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels.width),
                                         pixelsHigh: Int(pixels.height), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
