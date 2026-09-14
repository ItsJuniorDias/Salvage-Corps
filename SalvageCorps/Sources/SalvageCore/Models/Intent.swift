import Foundation

/// A intenção que um inimigo TELEGRAFA para o próximo turno.
///
/// Telegrafar significa que o jogador vê o que vai acontecer ANTES de decidir
/// suas cartas — essencial pra deckbuilders. Sem intents visíveis, o combate
/// vira coincidência em vez de tática.
public enum EnemyIntent: Equatable, Hashable, Codable {

    /// Vai atacar o jogador com X de dano.
    case attack(damage: Int)

    /// Vai atacar N vezes com X de dano cada (metralhadora tipo T2).
    case multiAttack(damage: Int, hits: Int)

    /// Vai ganhar block para si próprio.
    case defend(block: Int)

    /// Ataque psíquico: reduz Moral do jogador em vez de HP.
    case moralAttack(damage: Int)

    /// Ataque composto: dano físico + dano de Moral (Traumatizado).
    case attackAndMoral(damage: Int, moralDamage: Int)

    /// (Futuro) Invocar aliados. Ignorado no MVP.
    case summon(count: Int)

    /// Não faz nada — perdeu o turno (Empurrar Frente aplicado).
    case skip
}


/// Padrão de intenções que um inimigo cicla ao longo dos turnos.
///
/// Exemplo Metralhadora: [.defend(8), .multiAttack(damage: 4, hits: 3)]
/// Vira: T1 defende, T2 atira, T3 defende, T4 atira...
public struct IntentPattern: Equatable, Hashable, Codable {
    public let intents: [EnemyIntent]

    public init(_ intents: [EnemyIntent]) {
        precondition(!intents.isEmpty, "IntentPattern precisa de pelo menos 1 intent")
        self.intents = intents
    }

    /// Retorna a intenção para um dado número de turnos completados por este inimigo.
    public func intent(forTurn turn: Int) -> EnemyIntent {
        intents[turn % intents.count]
    }
}
