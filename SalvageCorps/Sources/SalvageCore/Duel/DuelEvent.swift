import Foundation

/// Um evento que aconteceu como resultado de uma action num duelo.
///
/// A UI usa isso pra:
/// 1. Tocar animações/sons quando eu jogo (Pow effects em cima da minha carta)
/// 2. **REPLAY do turno do oponente**: quando recebo matchData do server, eu
///    tenho o state ANTES e o state DEPOIS. Iterar por `state.events` me dá
///    a ordem exata do que ele fez — permite "assistir" o turno dele acontecer.
///
/// Todo evento inclui `playerID` (afetado ou atuador), porque em PvP importa
/// diferenciar "eu tomei dano" vs "meu oponente tomou dano".
public enum DuelEvent: Equatable, Codable {

    case duelStarted
    case turnStarted(playerID: String, turn: Int)

    case cardPlayed(playerID: String, cardID: UUID, cardName: String)

    /// Dano físico aplicado. `targetPlayerID` = quem recebeu. `blocked` = quanto o block absorveu.
    case damageDealt(targetPlayerID: String, amount: Int, blocked: Int)

    /// Dano à moral. `targetPlayerID` = quem recebeu.
    case moralChanged(targetPlayerID: String, delta: Int)

    /// HP mudou (dano ou heal). `delta` negativo = perdeu HP.
    case hpChanged(targetPlayerID: String, delta: Int)

    /// Player ganhou block.
    case blockGained(playerID: String, amount: Int)

    /// Status effect aplicado.
    case statusApplied(targetPlayerID: String, status: StatusEffect, stacks: Int)

    case cardsDrawn(playerID: String, count: Int)
    case cardDiscarded(playerID: String, cardID: UUID)
    case cardExhausted(playerID: String, cardID: UUID)
    case deckShuffled(playerID: String)

    /// Fadiga (No Man's Land): player tentou draw de pile vazio e tomou dano.
    case fatigueDamage(playerID: String, amount: Int)

    /// Player marcado pra skip do próximo turno (Empurrar Frente).
    case skipTurnApplied(targetPlayerID: String)

    /// Player teve turno pulado (efeito de skip resolvido no início do turno dele).
    case turnSkipped(playerID: String)

    case turnEnded(playerID: String)

    case duelWon(winnerID: String)
    case duelForfeit(loserID: String)
}
