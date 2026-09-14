import Foundation

/// Extensão de `PlayerState` pra suportar iniciar combate com HP/Moral
/// já reduzidos (vindo do `RunPlayerState` acumulado da run).
///
/// Uso: `PlayerState(currentHP: 42, maxHP: 60, currentMoral: 28, maxMoral: 40)`.
extension PlayerState {

    public init(
        currentHP: Int,
        maxHP: Int,
        currentMoral: Int,
        maxMoral: Int,
        maxEnergy: Int = 3
    ) {
        self.maxHP = maxHP
        self.hp = max(0, min(maxHP, currentHP))
        self.maxMoral = maxMoral
        self.moral = max(0, min(maxMoral, currentMoral))
        self.energy = 0
        self.maxEnergy = maxEnergy
        self.block = 0
        self.statusEffects = [:]
    }
}
