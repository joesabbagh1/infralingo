import Foundation

/// A SplitMix64 generator, so lessons can be replayed from a fixed seed in tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The app's source of randomness. Wraps an `any RandomNumberGenerator` so domain code can
/// stay non-generic, and seeds it in tests by passing a seed.
final class RNG {
    private var generator: any RandomNumberGenerator

    init(_ seed: UInt64? = nil) {
        generator = seed.map { SeededGenerator(seed: $0) } ?? SystemRandomNumberGenerator()
    }

    /// A shuffled copy of `items`.
    func shuffle<T>(_ items: [T]) -> [T] {
        var copy = items
        copy.shuffle(using: &generator)
        return copy
    }

    /// One element at random, or nil when there is nothing to pick from.
    func pick<T>(_ items: [T]) -> T? {
        items.randomElement(using: &generator)
    }
}
