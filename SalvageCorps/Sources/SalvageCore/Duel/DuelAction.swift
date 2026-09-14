import Foundation

/// Todas as ações possíveis num duelo PvP.
///
/// Cada action carrega `playerID` — o engine valida que quem está agindo é
/// o `activePlayerID`. Isso evita bug onde o cliente aplica sua própria action
/// como se fosse do oponente ao decodificar matchData.
///
/// **Simplificação vs single-player**: como PvP só tem 1 oponente (o outro
/// player), cartas que hoje têm `targeting = .singleEnemy` NÃO precisam
/// carregar `targetEnemyID` — o alvo é implícito. A UI resolve automaticamente
/// (não precisa mostrar picker).
public enum DuelAction: Equatable, Codable {

    /// Inicia o duelo. Embaralha os dois decks (com seeds separadas),
    /// compra 5 cartas pra cada player, prepara turno 1 do `activePlayerID`.
    /// Requer que AMBOS os `drawPile` já estejam populados. Falha em
    /// `.awaitingOpponentDeck` (fase de setup PvP com decks customizados).
    case startDuel

    /// **PvP setup**: player não-host submete seu deck depois do host ter criado
    /// o match. Só válido em `.awaitingOpponentDeck` e apenas pelo `activePlayerID`
    /// dessa fase (que é o oponente, não o host).
    ///
    /// Ao aplicar: preenche o `drawPile` do lado do submetente, chama
    /// `startDuel` internamente (embaralha ambos + saca 5 pra cada), muda
    /// phase pra `.active` e devolve `activePlayerID` pro `firstToPlay`
    /// original (o host).
    case submitOpponentDeck(playerID: String, deck: [Card])

    /// Player joga uma carta da mão.
    case playCard(
        playerID: String,
        handIndex: Int,
        targetHandIndex: Int? = nil
    )

    /// Player encerra seu turno.
    case endTurn(playerID: String)

    /// Player desiste do match.
    case forfeit(playerID: String)
}


/// Resultado de aplicar uma action. Se falhou, contém o motivo.
public enum DuelActionResult: Equatable {
    case applied(DuelState)
    case invalid(reason: DuelActionError)
}


public enum DuelActionError: String, Equatable, Error {
    case duelNotActive
    case duelAlreadyStarted
    case notYourTurn
    case unknownPlayer
    case invalidHandIndex
    case notEnoughEnergy
    case targetRequired
    case invalidTarget
    case cardHasNoValidTarget
    /// Efeito da carta não é suportado no modo duelo.
    case effectNotSupportedInDuel
    /// Tentou submeter deck fora da fase `.awaitingOpponentDeck`.
    case notInDeckSubmissionPhase
    /// Host tentou submeter deck oponente (só o não-host pode).
    case hostCantSubmitOpponentDeck
    /// Deck submetido tem tamanho errado.
    case deckWrongSize
    /// Deck submetido vazio (edge case; equivalente a deckWrongSize mas mais claro).
    case deckEmpty
}
