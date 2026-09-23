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
        save(Dialogs.aboutDialog().contentView, dir.appendingPathComponent("about.png"))
        save(Dialogs.helpDialog().contentView, dir.appendingPathComponent("help.png"))
        save(Dialogs.infoDialog().contentView, dir.appendingPathComponent("info.png"))
        save(Dialogs.settingsDialog(.defaults).contentView, dir.appendingPathComponent("settings.png"))
        save(Dialogs.errorDialog("Dead Meat !!!").contentView, dir.appendingPathComponent("error.png"))
    }

    private static func save(_ view: NSView, _ url: URL) {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
