import Foundation

/// Estado do jogador que PERSISTE entre combates dentro de uma run.
///
/// Diferente de `PlayerState`, que é volátil por combate. `RunPlayerState`
/// mantém HP e Moral acumulados ao longo dos combates + camps.
///
/// Ao iniciar combate: `PlayerState` recebe HP/Moral daqui.
/// Ao terminar combate: HP/Moral finais voltam pra cá.
/// No camp (repousar): cura aplicada aqui.
public struct RunPlayerState: Codable, Equatable, Sendable {

    public var hp: Int
    public var maxHP: Int
    public var moral: Int
    public var maxMoral: Int

    public init(
        hp: Int = 60,
        maxHP: Int = 60,
        moral: Int = 40,
        maxMoral: Int = 40
    ) {
        self.hp = hp
        self.maxHP = maxHP
        self.moral = moral
        self.maxMoral = maxMoral
    }

    // MARK: - Queries

    public var hpPercent: Double {
        guard maxHP > 0 else { return 0 }
        return Double(hp) / Double(maxHP)
    }

    public var moralPercent: Double {
        guard maxMoral > 0 else { return 0 }
        return Double(moral) / Double(maxMoral)
    }

    public var isDefeated: Bool { hp <= 0 || moral <= 0 }

    // MARK: - Mutations

    /// Repouso no acampamento. Default: +30% HP, +20% Moral (arredonda pra cima).
    public mutating func rest(hpFraction: Double = 0.30, moralFraction: Double = 0.20) {
        let hpGain = Int(ceil(Double(maxHP) * hpFraction))
        let moralGain = Int(ceil(Double(maxMoral) * moralFraction))
        hp = min(maxHP, hp + hpGain)
        moral = min(maxMoral, moral + moralGain)
    }

    /// Atualiza HP/Moral após combate (clamp aos limites).
    public mutating func updateFromCombat(hp finalHP: Int, moral finalMoral: Int) {
        hp = max(0, min(maxHP, finalHP))
        moral = max(0, min(maxMoral, finalMoral))
    }

    /// Muda HP atual com clamp automático.
    public mutating func changeHP(by delta: Int) {
        hp = max(0, min(maxHP, hp + delta))
    }

    /// Muda Moral atual com clamp automático.
    public mutating func changeMoral(by delta: Int) {
        moral = max(0, min(maxMoral, moral + delta))
    }

    /// Muda maxHP. Ajusta HP atual também (se ganhou max, ganhou atual proporcional).
    /// Se `delta` for negativo e novo max < atual, atual é clamped.
    public mutating func changeMaxHP(by delta: Int) {
        let newMax = max(1, maxHP + delta)
        maxHP = newMax
        if delta > 0 { hp += delta }  // ganho: dá HP correspondente
        hp = min(hp, maxHP)  // clamp se maxHP diminuiu
    }

    /// Idem pra Moral.
    public mutating func changeMaxMoral(by delta: Int) {
        let newMax = max(1, maxMoral + delta)
        maxMoral = newMax
        if delta > 0 { moral += delta }
        moral = min(moral, maxMoral)
    }
}
