/// The three game settings. In the original they were stored as 'BSet' 128 in
/// "Beast Game Settings" in the System Folder (src/BeastSettings.p).
public struct BeastSettings: Equatable {
    /// Number of beasts, 1...10.
    public var numBeasts: Int
    /// Ticks (1/60 s) between beast moves, 1...360.
    public var delay: Int
    /// Block density, 2...10: a new game places 558 / density blocks.
    public var density: Int

    public static let defaults = BeastSettings(numBeasts: 5, delay: 45, density: 5)

    public init(numBeasts: Int, delay: Int, density: Int) {
        self.numBeasts = numBeasts
        self.delay = delay
        self.density = density
    }

    /// [VERIFYSE]
    public func verified() -> BeastSettings {
        BeastSettings(numBeasts: min(max(numBeasts, 1), 10),
                      delay: min(max(delay, 1), 360),
                      density: min(max(density, 2), 10))
    }
}

/// Toolbox `StringToNum`: an optional sign, then digits. Anything unparsable becomes 0,
/// which `verified()` then raises to the minimum.
public func stringToNum(_ s: String) -> Int {
    var digits = s.drop { $0 == " " || $0 == "\t" }
    var sign = 1
    if let first = digits.first, first == "-" || first == "+" {
        sign = first == "-" ? -1 : 1
        digits = digits.dropFirst()
    }
    let prefix = digits.prefix { $0.isASCII && $0.isNumber }
    guard let value = Int(prefix.prefix(9)) else { return 0 }
    return sign * value
}
