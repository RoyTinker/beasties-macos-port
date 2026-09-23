import AppKit
import BeastCore

/// The application shell: [INIT], [SETUPMEN], [SETUPWIN], [DOMENUBA], the [CHECKEVE] loop
/// and [SHUTDOWN].
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var settings = SettingsStore.load()
    private lazy var game = BeastGame(settings: settings)
    private var window: NSWindow!
    private var board: BoardView!
    private var timer: Timer?
    private var drawnChangeCount = -1
    private var showingAlert = false

    /// `TickCount`: ticks (1/60 s) since the machine started.
    private var tickCount: Int {
        Int(ProcessInfo.processInfo.systemUptime * Double(BeastGame.ticksPerSecond))
    }

    // MARK: - Launch and quit

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenuBar()

        // WIND 128: 506 x 297, "Beast", with a close box.
        let size = NSSize(width: 506, height: 297)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Beast"
        window.delegate = self
        board = BoardView(game: game, frame: NSRect(origin: .zero, size: size))
        board.afterInput = { [unowned self] in self.update() }
        window.contentView = board
        window.makeFirstResponder(board)
        window.center()

        if let dir = Snapshot.directory {
            Snapshot.write(board: board, game: game, to: dir)
            NSApp.terminate(nil)
            return
        }
        window.makeKeyAndOrderFront(nil)

        // The original polled its timers on every pass through the event loop. A 60 Hz timer
        // does the same job. It runs in the default mode only, so the game stops while a menu
        // or dialog is open, just as it did when those blocked the old event loop.
        let timer = Timer(timeInterval: 1.0 / Double(BeastGame.ticksPerSecond), repeats: true) { [unowned self] _ in
            self.game.idle(now: self.tickCount)
            self.update()
        }
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true                                            // the close box quit the original
    }

    func applicationWillTerminate(_ notification: Notification) {
        SettingsStore.save(settings)                    // [SHUTDOWN] -> [SAVEBEAS]
    }

    /// Runs the beeps and alerts the game asked for, then redraws if anything changed.
    private func update() {
        if !showingAlert {
            showingAlert = true
            for item in game.takeFeedback() {
                switch item {
                case .beep:
                    NSSound.beep()
                case .alert(let message):
                    board.needsDisplay = true
                    board.displayIfNeeded()             // show the final move behind the alert
                    Dialogs.error(message)
                }
            }
            showingAlert = false
        }
        if game.changeCount != drawnChangeCount {
            drawnChangeCount = game.changeCount
            board.needsDisplay = true
        }
    }

    // MARK: - Menus ([SETUPMEN]: MENU 128, 129, 130)

    private func makeMenuBar() -> NSMenu {
        let bar = NSMenu()

        let app = submenu(of: bar, title: "Beast")
        app.addItem(withTitle: "About Beast…", action: #selector(about(_:)), keyEquivalent: "")
        app.addItem(.separator())
        let services = app.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
        services.submenu = NSMenu(title: "Services")
        NSApp.servicesMenu = services.submenu
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Beast", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)),
                    keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Beast", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // The original's File menu, with Quit moved to the app menu as macOS expects.
        let file = submenu(of: bar, title: "File")
        file.addItem(withTitle: "New Game", action: #selector(newGame(_:)), keyEquivalent: "n")
        file.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: "s")
        file.addItem(withTitle: "Pause", action: #selector(pause(_:)), keyEquivalent: "p")
        file.addItem(.separator())
        file.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        // Needed for the text fields in the Settings dialog. On the game window these show
        // the original's "for DAs only" alert (see BoardView).
        let edit = submenu(of: bar, title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Clear", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = submenu(of: bar, title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = windowMenu

        let help = submenu(of: bar, title: "Help")
        help.addItem(withTitle: "How to Play Beast", action: #selector(showHelp(_:)), keyEquivalent: "")
        NSApp.helpMenu = help

        return bar
    }

    private func submenu(of bar: NSMenu, title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.delegate = self
        bar.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
        return menu
    }

    /// In the original, any click resumed a paused game, including a click in the menu bar.
    func menuWillOpen(_ menu: NSMenu) {
        game.mouseDown()
    }

    /// ...and a drag of the title bar ([DOMOUSED], inDrag).
    func windowWillMove(_ notification: Notification) {
        game.mouseDown()
    }

    // MARK: - Commands ([DOMENUBA])

    @objc private func about(_ sender: Any?) {
        Dialogs.about()
    }

    @objc private func showHelp(_ sender: Any?) {
        Dialogs.help()
    }

    @objc private func newGame(_ sender: Any?) {
        game.newGame(seed: Int32(truncatingIfNeeded: tickCount))
        update()
    }

    @objc private func showSettings(_ sender: Any?) {
        settings = Dialogs.settings(settings)
        SettingsStore.save(settings)
        game.apply(settings)                            // applies at once, even mid-game
    }

    @objc private func pause(_ sender: Any?) {
        game.pause()
    }
}
