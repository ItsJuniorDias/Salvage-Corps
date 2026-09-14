import Foundation

/// Gerador de números aleatórios determinístico e seedeable.
///
/// Usa um Xorshift64* — rápido, alta qualidade estatística pra uso em jogos,
/// e reproduzível a partir de uma seed. Não use para criptografia.
///
/// Importante: TODA aleatoriedade do jogo deve passar por aqui. Isso permite:
/// - Replay exato de runs (mesma seed = mesma sequência)
/// - Daily challenges (seed derivada da data)
/// - Debug de bugs "impossíveis" (compartilhar seed)
public struct SeededRandom: RandomNumberGenerator, Codable, Equatable {

    private var state: UInt64

    public init(seed: UInt64) {
        // Evita seed 0 (Xorshift degenera com seed 0)
        self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed
    }

    public mutating func next() -> UInt64 {
        // Xorshift64* — proposto por Marsaglia, popularizado por Vigna.
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }

    /// Retorna um inteiro no range fechado [min, max].
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    /// Embaralha um array in-place de forma determinística.
    public mutating func shuffle<T>(_ array: inout [T]) {
        array.shuffle(using: &self)
    }

    /// Escolhe um elemento aleatório do array. Retorna nil se vazio.
    public mutating func pick<T>(from array: [T]) -> T? {
        array.randomElement(using: &self)
    }
}
