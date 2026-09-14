import Foundation

/// Estado completo de um combate em curso.
///
/// Tudo que o jogo precisa saber pra renderizar E pra decidir a próxima ação
/// está aqui. É serializável (Codable) → save/load trivial. É determinístico
/// (RNG interno) → replay/daily challenges trivial.
///
/// Trate como imutável: todas as mutações passam pelo `GameEngine.apply(...)`
/// que retorna um novo estado. Isso mantém a testabilidade e permite undo.
public struct GameState: Equatable, Codable {

    public var phase: CombatPhase
    public var turn: Int
    public var player: PlayerState
    public var enemies: [Enemy]

    public var drawPile: [Card]
    public var hand: [Card]
    public var discardPile: [Card]
    public var exhaustPile: [Card]

    public var rng: SeededRandom

    /// Log de eventos que aconteceram desde a última action. A UI consome pra
    /// mostrar animações/números flutuantes. Limpa a cada nova action.
    public var events: [CombatEvent]

    /// Se true, sistema de Corrupção está ativo (Ato 2+):
    /// - Jogar carta .corrupcao adiciona 1 stack de corruption ao player
    /// - Jogar carta .resolucao remove 1 stack
    /// - No start turn, player perde `corruption` de moral
    public let corruptionEnabled: Bool

    public init(
        player: PlayerState,
        enemies: [Enemy],
        deck: [Card],
        seed: UInt64,
        corruptionEnabled: Bool = false
    ) {
        self.phase = .notStarted
        self.turn = 0
        self.player = player
        self.enemies = enemies
        self.drawPile = deck
        self.hand = []
        self.discardPile = []
        self.exhaustPile = []
        self.rng = SeededRandom(seed: seed)
        self.events = []
        self.corruptionEnabled = corruptionEnabled
    }

    public var isCombatOver: Bool {
        switch phase {
        case .victory, .defeat: return true
        default: return false
        }
    }

    public var livingEnemies: [Enemy] { enemies.filter { $0.isAlive } }
}


public enum CombatPhase: Equatable, Codable {
    case notStarted
    case playerTurn
    case enemyTurn
    case victory
    case defeat(reason: DefeatReason)
}


/// Um evento que aconteceu como resultado de uma action.
/// A UI usa isso pra tocar animações/sons.
public enum CombatEvent: Equatable, Codable {
    case combatStarted
    case turnStarted(turn: Int)
    case cardPlayed(cardID: UUID, cardName: String)
    case damageDealt(targetID: UUID, amount: Int, blocked: Int)
    case damageDealtAll(amount: Int)
    case moralChanged(delta: Int)
    case playerHPChanged(delta: Int)
    case blockGained(amount: Int)
    case statusApplied(targetID: UUID?, status: StatusEffect, stacks: Int)
    case cardsDrawn(count: Int)
    case cardDiscarded(cardID: UUID)
    case cardExhausted(cardID: UUID)
    case deckShuffled
    case enemyDefeated(enemyID: UUID)
    case enemyIntentExecuted(enemyID: UUID, intent: EnemyIntent)
    case turnEnded
    case combatWon
    case combatLost(reason: DefeatReason)

    /// Boss entrou em nova fase. UI mostra banner + sfx + shake.
    case bossPhaseChanged(enemyID: UUID, newPhase: Int, intro: String?)
}
