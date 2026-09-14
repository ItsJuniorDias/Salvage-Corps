import Foundation

/// Um efeito único aplicável por uma carta.
///
/// Modelo declarativo: cada carta tem um `[CardEffect]` que é executado em
/// ordem. Isso permite composição fácil e evita cartas com lógica hardcoded.
/// Novo tipo de efeito? Adiciona um case aqui + implementação no CombatEngine.
public enum CardEffect: Equatable, Hashable, Codable {

    /// Dano físico ao alvo escolhido. Reduzido por Block do alvo.
    case damage(Int)

    /// Dano físico em TODOS os inimigos vivos.
    case damageAll(Int)

    /// Dano à Moral do jogador (usado por cartas de sacrifício/corrupção).
    case damageSelfMoral(Int)

    /// Ganha Block temporário. Zera no início do próximo turno do jogador.
    case gainBlock(Int)

    /// Ajusta a Moral do jogador (positivo = ganha, negativo = perde).
    case gainMoral(Int)

    /// Aplica X stacks de um status effect ao alvo escolhido.
    case applyStatus(StatusEffect, stacks: Int)

    /// Aplica X stacks de um status effect a todos inimigos.
    case applyStatusAll(StatusEffect, stacks: Int)

    /// Exila uma carta específica da mão (pelo índice).
    /// Usado por "Racionalizar".
    case exhaustFromHand(handIndex: Int)

    /// Exila UMA carta escolhida pelo jogador (targeting requerido).
    /// Diferente do anterior: aqui o targeting é feito na hora de jogar a carta.
    case exhaustChosenFromHand

    /// Compra N cartas.
    case draw(Int)

    /// Faz o alvo pular o próximo turno (Empurrar Frente).
    case skipNextTurn

    /// Revela intents de TODOS os inimigos por 1 turno.
    /// Cartas de "escuta" no Ato 2 usam isso.
    case revealAllIntents
}


/// Se uma carta requer alvo específico entre inimigos.
public enum CardTargeting: String, Equatable, Codable {
    /// Não precisa alvo (efeitos self ou área).
    case none
    /// Requer um inimigo alvo (dano single-target, status single-target).
    case singleEnemy
    /// Requer uma carta da própria mão (Racionalizar).
    case cardInHand
}
