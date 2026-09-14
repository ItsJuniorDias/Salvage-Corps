import Foundation

/// Estado do jogador durante um combate.
public struct PlayerState: Equatable, Codable {

    public var maxHP: Int
    public var hp: Int
    public var maxMoral: Int
    public var moral: Int

    /// Energia disponível NESTE turno. Zera e reseta no início de cada turno.
    public var energy: Int

    /// Energia máxima por turno (default 3).
    public var maxEnergy: Int

    /// Block temporário. Zera no início do próximo turno.
    public var block: Int

    /// Status effects ativos no jogador.
    public var statusEffects: [StatusEffect: Int]

    public init(
        maxHP: Int = 60,
        maxMoral: Int = 40,
        maxEnergy: Int = 3
    ) {
        self.maxHP = maxHP
        self.hp = maxHP
        self.maxMoral = maxMoral
        self.moral = maxMoral
        self.energy = 0
        self.maxEnergy = maxEnergy
        self.block = 0
        self.statusEffects = [:]
    }

    public var isDefeated: Bool { hp <= 0 || moral <= 0 }

    public var defeatReason: DefeatReason? {
        if hp <= 0 { return .hp }
        if moral <= 0 { return .moral }
        return nil
    }
}


public enum DefeatReason: String, Equatable, Codable {
    case hp
    case moral
}
