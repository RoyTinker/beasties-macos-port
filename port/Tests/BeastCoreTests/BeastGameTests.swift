@testable import BeastCore
import Testing

/// A game on an empty walled board, already playing and not paused.
private func makeGame(beasts: Int = 1, delay: Int = 10) -> BeastGame {
    let g = BeastGame(settings: BeastSettings(numBeasts: beasts, delay: delay, density: 5))
    g.playing = true
    g.paused = false
    return g
}

private func place(man x: Int, _ y: Int, in g: BeastGame) {
    g.man = GridPoint(h: x, v: y)
    g.setCell(x, y, .man)
}

private func place(beast i: Int, at x: Int, _ y: Int, in g: BeastGame) {
    g.beasts[i] = GridPoint(h: x, v: y)
    g.setCell(x, y, .beast)
}

private func count(_ cell: Cell, in g: BeastGame) -> Int {
    var n = 0
    for x in 1...BeastGame.columns {
        for y in 1...BeastGame.rows where g.cell(x, y) == cell {
            n += 1
        }
    }
    return n
}

private let key = (i: 73, j: 74, k: 75, l: 76)

@Suite struct RandomTests {
    @Test func parkMillerSequence() {
        var r = QDRandom(seed: 1)
        #expect(r.next() == 16807)
        #expect(r.seed == 16807)
        #expect(r.next() == Int16(truncatingIfNeeded: 282_475_249))
        #expect(r.seed == 282_475_249)
    }

    @Test func randStaysInRange() {
        let g = makeGame()
        g.random.seed = 12345
        for _ in 0..<5000 {
            #expect((0...28).contains(g.rand(28)))
            #expect((0...2).contains(g.rand(2)))
        }
    }
}

@Suite struct BoardTests {
    @Test func initMatrixBuildsAWalledEmptyBoard() {
        let g = makeGame()
        for x in 1...31 {
            for y in 1...18 {
                let edge = x == 1 || x == 31 || y == 1 || y == 18
                #expect(g.cell(x, y) == (edge ? .block : .empty))
            }
        }
        #expect(g.cell(0, 0) == .block, "outside the board reads as a block")
    }

    @Test func newGamePopulatesTheBoard() {
        let g = makeGame(beasts: 5)
        g.newGame(seed: 424242)
        #expect(g.playing)
        #expect(g.paused, "a new game waits for the first key or click")
        #expect(g.clock == 0)
        #expect(count(.man, in: g) == 1)
        #expect(g.cell(g.man.h, g.man.v) == .man)
        #expect(count(.beast, in: g) == 5)
        for i in 1...5 {
            #expect(g.cell(g.beasts[i].h, g.beasts[i].v) == .beast)
            #expect((2...30).contains(g.beasts[i].h) && (2...17).contains(g.beasts[i].v))
        }
        // 94 wall blocks plus 558 / 5 = 111 random ones, less any the beasts or man landed on.
        let blocks = count(.block, in: g)
        #expect(blocks <= 94 + 111 && blocks >= 94 + 111 - 6)
    }

    @Test func sameSeedSameBoard() {
        let a = makeGame(beasts: 3), b = makeGame(beasts: 3)
        a.newGame(seed: 99)
        b.newGame(seed: 99)
        for x in 1...31 {
            for y in 1...18 {
                #expect(a.cell(x, y) == b.cell(x, y))
            }
        }
    }
}

@Suite struct ManTests {
    @Test func stepsIntoEmptyCells() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.keyDown(charCode: key.l)
        #expect(g.man == GridPoint(h: 11, v: 10))
        #expect(g.cell(10, 10) == .empty && g.cell(11, 10) == .man)
        g.keyDown(charCode: key.i)
        #expect(g.man == GridPoint(h: 11, v: 9))
    }

    @Test func lowercaseKeysWork() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.keyDown(charCode: Int(UInt8(ascii: "j")))
        #expect(g.man == GridPoint(h: 9, v: 10))
        g.keyDown(charCode: Int(UInt8(ascii: "k")))
        #expect(g.man == GridPoint(h: 9, v: 11))
    }

    @Test func arrowKeysMoveLikeIJKL() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.arrowKey(.right)
        #expect(g.man == GridPoint(h: 11, v: 10))
        g.arrowKey(.down)
        #expect(g.man == GridPoint(h: 11, v: 11))
        g.arrowKey(.left)
        #expect(g.man == GridPoint(h: 10, v: 11))
        g.arrowKey(.up)
        #expect(g.man == GridPoint(h: 10, v: 10))
        #expect(g.takeFeedback().isEmpty, "arrows don't beep")
    }

    @Test func arrowKeysPushBlocksAndResumePlay() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.setCell(10, 9, .block)
        g.pause()
        g.arrowKey(.up)
        #expect(!g.paused)
        #expect(g.man == GridPoint(h: 10, v: 9) && g.cell(10, 8) == .block)
    }

    @Test func arrowKeysAreIgnoredWhenNotPlaying() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.playing = false
        g.arrowKey(.right)
        #expect(g.man == GridPoint(h: 10, v: 10))
    }

    @Test func otherKeysBeep() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.keyDown(charCode: Int(UInt8(ascii: "x")))
        #expect(g.takeFeedback() == [.beep(2)])
        #expect(g.man == GridPoint(h: 10, v: 10))
    }

    @Test func keysAreIgnoredWhenNotPlaying() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.playing = false
        g.keyDown(charCode: key.l)
        #expect(g.man == GridPoint(h: 10, v: 10))
        #expect(g.takeFeedback().isEmpty)
    }

    @Test func anyKeyResumesAPausedGame() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.pause()
        g.keyDown(charCode: Int(UInt8(ascii: "x")))
        #expect(!g.paused)
    }

    @Test func pushesARunOfBlocks() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.setCell(11, 10, .block)
        g.setCell(12, 10, .block)
        g.keyDown(charCode: key.l)
        #expect(g.man == GridPoint(h: 11, v: 10))
        #expect(g.cell(10, 10) == .empty)
        #expect(g.cell(11, 10) == .man)
        #expect(g.cell(12, 10) == .block && g.cell(13, 10) == .block)
    }

    @Test func aBeastStopsAPush() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        g.setCell(11, 10, .block)
        place(beast: 1, at: 12, 10, in: g)
        g.keyDown(charCode: key.l)
        #expect(g.man == GridPoint(h: 10, v: 10))
        #expect(g.cell(11, 10) == .block && g.cell(12, 10) == .beast)
    }

    @Test func theWallStopsAPush() {
        let g = makeGame()
        place(man: 3, 10, in: g)
        g.setCell(2, 10, .block)
        g.keyDown(charCode: key.j)                          // blocks at x = 2 and x = 1 (wall)
        #expect(g.man == GridPoint(h: 3, v: 10))
        #expect(g.cell(2, 10) == .block && g.cell(1, 10) == .block)
    }

    @Test func walkingIntoABeastIsFatal() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        place(beast: 1, at: 10, 11, in: g)
        g.keyDown(charCode: key.k)
        #expect(!g.playing)
        #expect(g.takeFeedback() == [.alert("Dead Meat !!!")])
        #expect(g.man == GridPoint(h: 10, v: 10))
    }
}

@Suite struct BeastTests {
    @Test func beastsChaseDiagonally() {
        let g = makeGame()
        place(man: 20, 15, in: g)
        place(beast: 1, at: 10, 5, in: g)
        g.doMoveBeasts()
        #expect(g.beasts[1] == GridPoint(h: 11, v: 6))
        #expect(g.cell(10, 5) == .empty && g.cell(11, 6) == .beast)
    }

    @Test func beastsChaseStraightWhenAligned() {
        let g = makeGame()
        place(man: 10, 15, in: g)
        place(beast: 1, at: 10, 5, in: g)
        g.doMoveBeasts()
        #expect(g.beasts[1] == GridPoint(h: 10, v: 6))
    }

    @Test func reachingTheManIsFatal() {
        let g = makeGame()
        place(man: 10, 10, in: g)
        place(beast: 1, at: 11, 11, in: g)
        g.doMoveBeasts()
        #expect(!g.playing)
        #expect(g.takeFeedback() == [.alert("Dead Meat!!!")])
        #expect(g.cell(10, 10) == .beast)
    }

    @Test func aBeastInTheWayMakesItWait() {
        let g = makeGame(beasts: 2)
        place(man: 20, 5, in: g)
        place(beast: 1, at: 10, 5, in: g)
        place(beast: 2, at: 11, 5, in: g)
        g.random.seed = 7
        g.doMoveBeasts()
        // Beast 1 moves first and finds beast 2 in its way; then beast 2 steps east.
        #expect(g.beasts[1] == GridPoint(h: 10, v: 5))
        #expect(g.beasts[2] == GridPoint(h: 12, v: 5))
        #expect(g.cell(11, 5) == .empty)
    }

    @Test func aBlockedBeastOnlyMovesIntoEmptyCells() {
        let g = makeGame()
        place(man: 20, 5, in: g)
        place(beast: 1, at: 10, 5, in: g)
        g.setCell(11, 5, .block)
        for seed: Int32 in 1...200 {
            g.random.seed = seed
            let before = g.beasts[1]
            g.doMoveBeasts()
            let after = g.beasts[1]
            #expect(abs(after.h - before.h) <= 1 && abs(after.v - before.v) <= 1)
            #expect(count(.beast, in: g) == 1)
            #expect(count(.block, in: g) == 94 + 1, "a beast never destroys a block")
        }
    }

    @Test func trappingEveryBeastWins() {
        let g = makeGame()
        place(man: 20, 10, in: g)
        place(beast: 1, at: 10, 10, in: g)
        for x in 9...11 {
            for y in 9...11 where !(x == 10 && y == 10) {
                g.setCell(x, y, .block)
            }
        }
        g.doMoveBeasts()
        #expect(!g.playing)
        #expect(g.takeFeedback() == [.alert("You Win!!!")])
    }

    @Test func aBeastNextToTheManIsNotTrapped() {
        let g = makeGame()
        place(beast: 1, at: 10, 10, in: g)
        for x in 9...11 {
            for y in 9...11 where !(x == 10 && y == 10) {
                g.setCell(x, y, .block)
            }
        }
        place(man: 11, 11, in: g)
        #expect(g.openSpace(10, 10))
    }

    @Test func unplacedBeastSlotsStayPut() {
        // Raising the beast count mid-game activates slots at (0, 0). They must not crash.
        let g = makeGame(beasts: 1)
        place(man: 20, 10, in: g)
        place(beast: 1, at: 10, 10, in: g)
        g.apply(BeastSettings(numBeasts: 3, delay: 10, density: 5))
        g.doMoveBeasts()
        #expect(g.beasts[2] == GridPoint(h: 0, v: 0))
        #expect(g.beasts[1] == GridPoint(h: 11, v: 10))
    }
}

@Suite struct TimingTests {
    @Test func clockAndBeastsRunOnTheirOwnTimers() {
        let g = makeGame(delay: 30)
        place(man: 25, 10, in: g)
        place(beast: 1, at: 5, 10, in: g)
        g.idle(now: 1000)                               // timers start at 0: both fire
        #expect(g.clock == 1)
        #expect(g.beasts[1].h == 6)
        g.idle(now: 1029)                               // neither is due yet
        #expect(g.clock == 1 && g.beasts[1].h == 6)
        g.idle(now: 1031)                               // beasts due (1000 + 30)
        #expect(g.clock == 1 && g.beasts[1].h == 7)
        g.idle(now: 1061)                               // clock due (1000 + 60)
        #expect(g.clock == 2)
    }

    @Test func nothingRunsWhilePaused() {
        let g = makeGame()
        place(man: 25, 10, in: g)
        place(beast: 1, at: 5, 10, in: g)
        g.pause()
        g.idle(now: 5000)
        #expect(g.clock == 0 && g.beasts[1].h == 5)
        g.mouseDown()
        g.idle(now: 5001)
        #expect(g.clock == 1 && g.beasts[1].h == 6)
    }
}

@Suite struct SettingsTests {
    @Test func verifyClampsEachValue() {
        #expect(BeastSettings(numBeasts: 0, delay: 0, density: 1).verified()
                == BeastSettings(numBeasts: 1, delay: 1, density: 2))
        #expect(BeastSettings(numBeasts: 11, delay: 1000, density: 50).verified()
                == BeastSettings(numBeasts: 10, delay: 360, density: 10))
        #expect(BeastSettings.defaults.verified() == BeastSettings.defaults)
    }

    @Test func stringToNumParsesLikeTheToolbox() {
        #expect(stringToNum("45") == 45)
        #expect(stringToNum(" -3") == -3)
        #expect(stringToNum("12abc") == 12)
        #expect(stringToNum("abc") == 0)
        #expect(stringToNum("") == 0)
    }
}
