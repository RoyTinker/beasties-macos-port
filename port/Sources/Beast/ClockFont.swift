import AppKit

/// A small bitmap font for the "Time: n" clock, in the style of a 1980s 9-point Mac font.
/// A vector font rendered this small without antialiasing turns into mush, so the clock
/// uses hand-made pixels like the original did.
enum ClockFont {
    /// 7 rows each, top to bottom. The bottom row sits just above the baseline.
    private static let glyphs: [Character: [String]] = [
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "i": ["#", ".", "#", "#", "#", "#", "#"],
        "m": [".....", ".....", "####.", "#.#.#", "#.#.#", "#.#.#", "#.#.#"],
        "e": ["....", "....", ".##.", "#..#", "####", "#...", ".###"],
        ":": [".", ".", ".", "#", ".", ".", "#"],
        " ": ["...", "...", "...", "...", "...", "...", "..."],
        "-": ["...", "...", "...", "###", "...", "...", "..."],
        "0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ]

    /// Draws `text` bold, with its baseline at `origin.y`, in the current y-down (flipped)
    /// context. QuickDraw bold draws each glyph twice, the second time 1 pixel to the right,
    /// and widens the advance by 1.
    static func draw(_ text: String, at origin: NSPoint) {
        NSColor.black.setFill()
        var x = origin.x
        for ch in text {
            guard let rows = glyphs[ch] else { continue }
            for (r, row) in rows.enumerated() {
                for (c, bit) in row.enumerated() where bit == "#" {
                    NSRect(x: x + CGFloat(c), y: origin.y - 7 + CGFloat(r), width: 2, height: 1).fill()
                }
            }
            x += CGFloat(rows[0].count) + 2                  // glyph + bold pixel + 1 px gap
        }
    }
}
