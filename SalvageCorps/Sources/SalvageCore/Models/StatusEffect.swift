import Foundation

/// Status effects que podem estar ativos em jogador ou inimigos.
///
/// Cada instância no state é `(effect: StatusEffect, stacks: Int)`.
/// Regras de decay/persistência dependem do tipo — implementadas no CombatEngine.
public enum StatusEffect: String, Equatable, Hashable, Codable, CaseIterable {

    /// Reduz próximo dano físico recebido pelos stacks.
    /// Zera automaticamente no início do turno do jogador.
    case block

    /// Alvo com Medo dá -stacks de dano no próximo ataque.
    /// Decrementa 1 stack por turno. Some quando chega a 0.
    case fear

    /// (Reservado pra futuro) Fadiga: perde 1 energia no próximo turno.
    case fatigue

    /// (Reservado pra futuro) Corrupção: acumula pra gatilhos meta.
    case corruption

    /// Marca que o afetado vai pular o próximo turno dele. Uso primário no
    /// modo duelo PvP (efeito de "Empurrar Frente" no oponente). Resolvido e
    /// removido no handoff dentro de `DuelEngine.applyEndTurn`. No single-player,
    /// enemies usam o campo `Enemy.skipNextTurn` em vez deste — este case é
    /// dedicado ao PlayerState.
    case skipNextTurn
}
