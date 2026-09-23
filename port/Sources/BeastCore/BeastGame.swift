// The Beast game logic, translated routine by routine from src/Beast.p.
//
// Each method names the original routine it comes from (the 8-character MacsBug name in
// brackets) so it can be checked against the Pascal and the disassembly. Behaviour is kept
// exactly, including the quirks listed in README.md. The one deliberate difference is
// `cell(_:_:)`: the original reads memory outside the board without checking, and here
// that returns `.block` instead. See the comment there.

/// What a board cell holds. The raw values match the original, which also used them to
/// index the sprite PICTs (200 + value).
public enum Cell: UInt8, CaseIterable {
    case man = 0
    case block = 1
    case beast = 2
    case empty = 3
}

/// A board position. As in the original's QuickDraw `Point`s, `h` is the column (x) and `v`
/// is the row (y).
public struct GridPoint: Equatable {
    public var h: Int
    public var v: Int

    public init(h: Int, v: Int) {
        self.h = h
        self.v = v
    }
}

/// Things the original did through the Toolbox in the middle of game logic. The app runs
/// them after each call into the game.
public enum Feedback: Equatable {
    /// `SysBeep(duration)`
    case beep(Int)
    /// `Error(msg)`: ALRT 129 with the message and an OK button.
    case alert(String)
}

public final class BeastGame {
    public static let columns = 31
    public static let rows = 18
    public static let cellSize = 16
    public static let maxBeasts = 10
    /// Ticks per second: the original's time unit is the 1/60 s tick.
    public static let ticksPerSecond = 60

    // gBoard: packed array[1..31, 1..18] of 0..3
    private var board: [Cell]

    /// gMan
    public internal(set) var man = GridPoint(h: 0, v: 0)
    /// gBeasts: array[1..10] of Point. Index 0 is unused so the numbering matches.
    /// Slots keep their old positions between games, which matters if the beast count is
    /// raised mid-game.
    public internal(set) var beasts = Array(repeating: GridPoint(h: 0, v: 0), count: maxBeasts + 1)
    /// gTimers: tick at which the beasts (0) and the clock (1) next update.
    public internal(set) var timers = [0, 0]
    /// gClock: seconds of play, shown as "Time: n".
    public internal(set) var clock = 0
    /// gPlaying
    public internal(set) var playing = false
    /// gPaused
    public internal(set) var paused = false

    /// gBeastDelay: ticks between beast moves.
    public var beastDelay: Int
    /// gNumBeasts
    public var numBeasts: Int
    /// gDensity: each game places `558 / density` blocks.
    public var density: Int

    /// QuickDraw's randSeed, reseeded from the tick count at every new game.
    public var random = QDRandom(seed: 1)

    /// Goes up whenever anything visible changes (a cell or the clock), so the app knows
    /// when to redraw.
    public private(set) var changeCount = 0

    private var pendingFeedback: [Feedback] = []

    /// [INITBEAS], minus the Toolbox work (settings file, PICTs), which the app does.
    public init(settings: BeastSettings) {
        board = Array(repeating: .empty, count: Self.columns * Self.rows)
        beastDelay = settings.delay
        numBeasts = settings.numBeasts
        density = settings.density
        initMatrix()
        playing = false
        paused = false
        clock = 0
    }

    // MARK: - Board access

    /// The contents of cell (x, y), with x in 1...31 and y in 1...18.
    ///
    /// The original never checks bounds in `OpenSpace` or in `MoveBeast`'s random retry.
    /// Normally that is safe, because the solid border keeps every beast inside. But raising
    /// the beast count mid-game activates slots that were never placed, which can sit at
    /// (0, 0), and the original then reads whatever globals lie next to the board. Here those
    /// reads return `.block`, so such a beast simply never moves.
    public func cell(_ x: Int, _ y: Int) -> Cell {
        guard (1...Self.columns).contains(x), (1...Self.rows).contains(y) else { return .block }
        return board[(x - 1) * Self.rows + (y - 1)]
    }

    func setCell(_ x: Int, _ y: Int, _ value: Cell) {
        guard (1...Self.columns).contains(x), (1...Self.rows).contains(y) else { return }
        board[(x - 1) * Self.rows + (y - 1)] = value
        changeCount += 1
    }

    /// Returns and clears the beeps and alerts produced since the last call.
    public func takeFeedback() -> [Feedback] {
        defer { pendingFeedback = [] }
        return pendingFeedback
    }

    private func error(_ message: String) {
        pendingFeedback.append(.alert(message))
    }

    private func sysBeep(_ duration: Int) {
        pendingFeedback.append(.beep(duration))
    }

    // MARK: - Setup

    /// [RAND] Returns 0...n.
    func rand(_ n: Int) -> Int {
        abs(Int(random.next()) % (n + 1))
    }

    /// [INITMATR] An empty board inside a wall of blocks.
    func initMatrix() {
        for x in 1...Self.columns {
            for y in 1...Self.rows {
                setCell(x, y, .empty)
            }
        }
        for x in 1...Self.columns {
            setCell(x, 1, .block)
            setCell(x, Self.rows, .block)
        }
        for y in 1...Self.rows {
            setCell(1, y, .block)
            setCell(Self.columns, y, .block)
        }
    }

    /// [RANDOMMA]
    func randomMatrix(density: Int, seed: Int32) {
        random.seed = seed                          // randSeed := TickCount
        let blocks = 558 / density                  // 558 = 31 * 18
        if blocks >= 1 {
            for _ in 1...blocks {
                var x: Int, y: Int
                repeat {
                    x = rand(28) + 2                // 2...30
                    y = rand(15) + 2                // 2...17
                } while cell(x, y) != .empty
                setCell(x, y, .block)
            }
        }
        if numBeasts >= 1 {
            for i in 1...numBeasts {
                var x: Int, y: Int
                repeat {
                    x = rand(28) + 2
                    y = rand(15) + 2
                } while cell(x, y) == .beast        // quirk: can land on, and replace, a block
                beasts[i] = GridPoint(h: x, v: y)
                setCell(x, y, .beast)
            }
        }
        var x: Int, y: Int
        repeat {
            x = rand(28) + 2
            y = rand(15) + 2
        } while cell(x, y) == .beast                // quirk: the man can replace a block too
        man = GridPoint(h: x, v: y)
        setCell(x, y, .man)
    }

    // MARK: - The man

    /// [MOVEMANT] Try to move the man one cell.
    func moveManTo(dx: Int, dy: Int) {
        let newX = man.h + dx
        let newY = man.v + dy

        // [MANMOVE], nested in MOVEMANT
        func manMove() {
            setCell(man.h, man.v, .empty)
            setCell(newX, newY, .man)
            man = GridPoint(h: newX, v: newY)
        }

        // [PUSHBLOC], nested in MOVEMANT. Slide the whole run of blocks in front of the man
        // one cell, if there's an empty cell at the end of it. A beast or the edge stops it.
        func pushBlock() {
            var x = man.h + dx
            var y = man.v + dy
            var foundSpace = false
            var blocked = false
            repeat {
                if (1...Self.columns).contains(x), (1...Self.rows).contains(y) {
                    switch cell(x, y) {
                    case .block:
                        x += dx
                        y += dy
                    case .beast:
                        blocked = true
                    default:
                        foundSpace = true
                    }
                } else {
                    blocked = true
                }
            } while !(foundSpace || blocked)
            if foundSpace {
                setCell(x, y, .block)
                manMove()                           // the man steps into the first block's cell
            }
        }

        guard (1...Self.columns).contains(newX), (1...Self.rows).contains(newY) else { return }
        switch cell(newX, newY) {
        case .block:
            pushBlock()
        case .beast:
            error("Dead Meat !!!")
            playing = false
        case .empty:
            manMove()
        case .man:
            break
        }
    }

    /// [DOMOVEMA] I/J/K/L = up/left/down/right. Any other key beeps.
    func doMoveMan(key: Int) {
        let dx: Int, dy: Int
        switch key {
        case 73: (dx, dy) = (0, -1)     // I
        case 74: (dx, dy) = (-1, 0)     // J
        case 75: (dx, dy) = (0, 1)      // K
        case 76: (dx, dy) = (1, 0)      // L
        default:
            sysBeep(2)
            return
        }
        moveManTo(dx: dx, dy: dy)
    }

    // MARK: - The beasts

    /// [MOVEBEAS] Move beast `i` by (dx, dy) if it can.
    func moveBeast(_ i: Int, dx: Int, dy: Int) {
        // [BEASTMOV], nested in MOVEBEAS
        func beastMove(to x: Int, _ y: Int) {
            setCell(beasts[i].h, beasts[i].v, .empty)
            setCell(x, y, .beast)
            beasts[i] = GridPoint(h: x, v: y)
        }

        var x = beasts[i].h + dx
        var y = beasts[i].v + dy
        guard (1...Self.columns).contains(x), (1...Self.rows).contains(y) else { return }
        switch cell(x, y) {
        case .man, .empty:
            let killsMan = cell(x, y) == .man
            beastMove(to: x, y)
            if killsMan {
                error("Dead Meat!!!")
                playing = false
            }
        case .block:
            // Blocked: try one random direction instead, with dx and dy each in -1...1.
            let rdx = rand(2) - 1
            let rdy = rand(2) - 1
            x = beasts[i].h + rdx
            y = beasts[i].v + rdy
            if cell(x, y) == .empty {
                beastMove(to: x, y)
            }
        case .beast:
            break                                   // another beast is in the way: wait
        }
    }

    /// [OPENSPAC], nested in DOMOVEBE. True if any of the 9 cells centred on (x, y) is empty
    /// or holds the man.
    func openSpace(_ x: Int, _ y: Int) -> Bool {
        var found = false
        for i in (x - 1)...(x + 1) {
            for j in (y - 1)...(y + 1) where cell(i, j) == .man || cell(i, j) == .empty {
                found = true
            }
        }
        return found
    }

    /// [DOMOVEBE] Every beast that isn't trapped takes one step toward the man.
    func doMoveBeasts() {
        var allTrapped = true
        if numBeasts >= 1 {
            for i in 1...numBeasts where openSpace(beasts[i].h, beasts[i].v) {
                allTrapped = false
                // Quirk: the original picks a random direction and then overwrites it. The
                // calls are kept because they advance the random sequence.
                _ = rand(2)
                _ = rand(2)
                let b = beasts[i]
                let dy = b.v > man.v ? -1 : (b.v < man.v ? 1 : 0)
                let dx = b.h > man.h ? -1 : (b.h < man.h ? 1 : 0)
                moveBeast(i, dx: dx, dy: dy)
            }
        }
        if allTrapped {
            error("You Win!!!")
            playing = false
        }
    }

    // MARK: - Timing

    /// [CHECKTIM] `now` is the current time in ticks (1/60 s).
    func checkTime(now: Int) {
        for t in 0...1 where now > timers[t] {
            let delay: Int
            if t == 0 {
                doMoveBeasts()
                delay = beastDelay
            } else {
                clock += 1
                changeCount += 1
                delay = Self.ticksPerSecond
            }
            timers[t] = now + delay
        }
    }

    // MARK: - Entry points for the app
    //
    // These are the parts of DOMENUBA, DOKEYDOW, DOMOUSED and CHECKEVE that touch game state.

    /// The tail of [CHECKEVE], run on every pass through the event loop.
    public func idle(now: Int) {
        if !paused && playing {
            checkTime(now: now)
        }
    }

    /// File > New Game. `seed` becomes randSeed; the original used `TickCount`.
    public func newGame(seed: Int32) {
        initMatrix()
        randomMatrix(density: density, seed: seed)
        clock = 0
        changeCount += 1
        timers = [0, 0]
        playing = true
        paused = true                               // play starts on the first key or click
    }

    /// File > Settings…, after the dialog closes. It applies straight away, even mid-game.
    public func apply(_ settings: BeastSettings) {
        beastDelay = settings.delay
        numBeasts = settings.numBeasts
        density = settings.density
    }

    /// File > Pause
    public func pause() {
        paused = true
    }

    /// [DOKEYDOW] for a key without ⌘. `charCode` is the typed character in Mac Roman or ASCII.
    public func keyDown(charCode: Int) {
        guard playing else { return }
        var key = charCode
        if key > 90 {                               // > 'Z': the original's crude upcase
            key = key - 97 + 65
        }
        doMoveMan(key: key)
        if paused {
            paused = false
        }
    }

    public enum Arrow {
        case up, left, down, right
    }

    /// Arrow keys: new in the port. Each acts exactly like its I/J/K/L key.
    public func arrowKey(_ arrow: Arrow) {
        switch arrow {
        case .up: keyDown(charCode: 73)             // I
        case .left: keyDown(charCode: 74)           // J
        case .down: keyDown(charCode: 75)           // K
        case .right: keyDown(charCode: 76)          // L
        }
    }

    /// [DOMOUSED] Any mouse-down resumes a paused game: in the window, the menu bar or the
    /// title bar.
    public func mouseDown() {
        if paused {
            paused = false
        }
    }

    /// [DOMOUSED], inContent: a click in the game window beeps.
    public func contentClick() {
        mouseDown()
        sysBeep(1)
    }
}
