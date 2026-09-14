import Foundation

/// Helpers pra construir DuelState iniciais.
///
/// O MVP usa deck fixo (Edmund starter) pros dois lados — simetria máxima
/// pra testar puramente o fluxo PvP sem variáveis extras de deck. Fases
/// futuras adicionam `edmundDuel(playerA:playerB:playerADeck:playerBDeck:)`
/// aceitando decks customizados.
public enum DuelFactory {

    /// Cria um duelo starter com o deck fixo de Edmund pros dois lados.
    ///
    /// - Parameters:
    ///   - playerAID: identificador do player A (host do match)
    ///   - playerBID: identificador do player B (guest)
    ///   - firstToPlay: quem começa jogando. Default: playerA.
    ///   - seedA / seedB: seeds pros RNGs isolados dos dois decks. Default: aleatório.
    ///     Passe seeds fixas em testes pra reproduzibilidade.
    ///
    /// - Returns: `DuelState` com `phase = .notStarted`. Chame
    ///   `DuelEngine.apply(.startDuel, to: state)` pra começar de fato.
    public static func edmundVsEdmund(
        playerAID: String,
        playerBID: String,
        firstToPlay: String? = nil,
        seedA: UInt64 = UInt64.random(in: 1...UInt64.max),
        seedB: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> DuelState {
        let deckA = StarterDeck.edmundStartingDeck()
        let deckB = StarterDeck.edmundStartingDeck()

        let stateA = DuelPlayerState(
            playerID: playerAID,
            player: PlayerState(),
            deck: deckA,
            seed: seedA
        )
        let stateB = DuelPlayerState(
            playerID: playerBID,
            player: PlayerState(),
            deck: deckB,
            seed: seedB
        )

        return DuelState(
            playerA: stateA,
            playerB: stateB,
            firstToPlay: firstToPlay ?? playerAID
        )
    }

    /// **Fluxo PvP com decks customizados**: cria state em `.awaitingOpponentDeck`.
    ///
    /// Host (creator) já submete seu deck. Oponente vai submeter o dele via
    /// `DuelAction.submitOpponentDeck` quando abrir o match — engine então
    /// embaralha os dois, saca mãos, transita pra `.active` e devolve a vez pro
    /// `firstToPlay` original.
    ///
    /// - Parameters:
    ///   - hostID: identificador do player que criou o match
    ///   - opponentID: identificador do oponente (encontrado via auto-match)
    ///   - hostDeck: `[Card]` já materializado do host (com UUIDs frescos —
    ///     use `DuelDeckConfig.toCardList()`)
    ///   - firstToPlay: quem começa quando duelo entrar em `.active`. Default: host.
    ///   - seedHost / seedOpponent: seeds pros RNGs (padrão aleatório)
    ///
    /// - Returns: `DuelState` com `phase = .awaitingOpponentDeck`,
    ///   `playerA = host`, `playerB = opponent` (drawPile vazio),
    ///   `activePlayerID = opponentID` (quem precisa agir primeiro).
    public static func createHostedDuel(
        hostID: String,
        opponentID: String,
        hostDeck: [Card],
        firstToPlay: String? = nil,
        seedHost: UInt64 = UInt64.random(in: 1...UInt64.max),
        seedOpponent: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> DuelState {
        let hostState = DuelPlayerState(
            playerID: hostID,
            player: PlayerState(),
            deck: hostDeck,
            seed: seedHost
        )
        // Deck do oponente é vazio — vai ser preenchido pela .submitOpponentDeck
        let opponentState = DuelPlayerState(
            playerID: opponentID,
            player: PlayerState(),
            deck: [],
            seed: seedOpponent
        )

        var state = DuelState(
            playerA: hostState,
            playerB: opponentState,
            firstToPlay: firstToPlay ?? hostID
        )
        // Transiciona pra fase de setup PvP e passa a vez pro oponente (quem
        // precisa submeter deck).
        state.phase = .awaitingOpponentDeck
        state.activePlayerID = opponentID
        // firstToPlayID já foi setado pelo init pro firstToPlay original.
        // Quando o oponente submeter, engine restaura activePlayerID pra ele.
        return state
    }
}
