import Foundation

/// Estado de um lado do duelo PvP.
///
/// Análogo ao `GameState` do single-player, mas por LADO — ou seja, `hand`,
/// piles e RNG ficam aqui em vez de num state global. Isso é importante:
///
/// 1. **Simetria natural**: playerA e playerB são structs idênticas. Sem
///    "player" vs "enemy" — ambos são players com HP/Moral/deck iguais.
/// 2. **RNG isolado**: cada lado tem sua própria seed. Player A não vê o
///    RNG de B, o que impede prever draws do oponente e trapacear.
/// 3. **Serialização enxuta**: cabe em ~5-8KB por lado. Duelo inteiro fica
///    bem abaixo do limite de 64KB do GKTurnBasedMatch.matchData.
///
/// Reusa `PlayerState` (HP/Moral/Block/Energy/Status) sem mudança —
/// o balanceamento single-player fica intocado.
public struct DuelPlayerState: Equatable, Codable {

    /// Identificador do player. No app iOS será `GKPlayer.gamePlayerID`, mas
    /// o Core não conhece GameKit — é só uma string opaca.
    public let playerID: String

    /// Estado de recursos do player (HP, Moral, Block, Energy, StatusEffects).
    /// Reusa a mesma struct do single-player, com valores default 60/40/3.
    public var player: PlayerState

    public var drawPile: [Card]
    public var hand: [Card]
    public var discardPile: [Card]
    public var exhaustPile: [Card]

    /// RNG deste lado. Deve ser inicializado com seed diferente da do oponente.
    public var rng: SeededRandom

    /// Fadiga acumulada — "No Man's Land".
    /// Quando o player tenta comprar de pile vazio (após reshuffle também estar
    /// vazio), sofre dano crescente: 1 na primeira vez, 2 na segunda, 3, 4...
    /// Impede stall infinito no fim do duelo.
    public var fatigueCounter: Int

    public init(
        playerID: String,
        player: PlayerState = PlayerState(),
        deck: [Card],
        seed: UInt64
    ) {
        self.playerID = playerID
        self.player = player
        self.drawPile = deck
        self.hand = []
        self.discardPile = []
        self.exhaustPile = []
        self.rng = SeededRandom(seed: seed)
        self.fatigueCounter = 0
    }

    /// Total de cartas no controle deste player (draw + hand + discard).
    /// Exílio não conta — cartas exiladas saíram permanentemente.
    public var totalCardsInPlay: Int {
        drawPile.count + hand.count + discardPile.count
    }

    public var isDefeated: Bool { player.isDefeated }

    public var defeatReason: DefeatReason? { player.defeatReason }
}
