/// QuickDraw's `Random` function.
///
/// QuickDraw uses the Park–Miller "minimal standard" generator:
/// `randSeed := randSeed * 16807 mod (2^31 - 1)`, returning the low 16 bits of the new seed
/// as a signed Integer, with -32768 mapped to 0.
/// This follows the documented algorithm. It has not been checked against a real ROM.
public struct QDRandom {
    /// QuickDraw's `randSeed` global.
    public var seed: Int32

    public init(seed: Int32) {
        self.seed = seed
    }

    public mutating func next() -> Int16 {
        let s = (Int64(seed & 0x7FFF_FFFF) * 16807) % 0x7FFF_FFFF
        seed = Int32(s)
        let low = Int16(truncatingIfNeeded: s)
        return low == Int16.min ? 0 : low
    }
}
