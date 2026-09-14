import Foundation

/// Estado completo de um duelo PvP async.
///
/// **É isto que vai virar `matchData` do `GKTurnBasedMatch`.** Serialização
/// via JSONEncoder padrão. Tamanho esperado: ~10-15KB em duelo médio (bem
/// abaixo do limite de 64KB da Apple).
///
/// Análogo ao `GameState` do single-player, mas simétrico: dois `DuelPlayerState`
/// em vez de um player + array de enemies.
///
/// `version` existe pra rejeitar matchData de builds futuros incompatíveis —
/// se o oponente atualizou o app antes de você e a struct mudou, você recebe
/// erro claro em vez de crash silencioso.
public struct DuelState: Equatable, Codable {

    /// Versão do formato de serialização. Increment em toda mudança breaking.
    public static let currentVersion: Int = 1

    public var version: Int
    public var phase: DuelPhase
    public var turn: Int
    public var playerA: DuelPlayerState
    public var playerB: DuelPlayerState

    /// ID do player que joga AGORA. Deve bater com playerA.playerID ou playerB.playerID.
    public var activePlayerID: String

    /// ID do player que começa jogando quando o duelo entrar em `.active`.
    /// Preservado através da fase `.awaitingOpponentDeck` — quando o oponente
    /// submete deck, engine devolve `activePlayerID` pra esse valor.
    /// Nil = usa o `activePlayerID` corrente no momento do startDuel.
    public var firstToPlayID: String?

    /// Log de eventos do turno atual (do `activePlayerID`). ACUMULA durante o turno:
    /// primeira playCard adiciona, segunda playCard adiciona ao final, endTurn preserva
    /// tudo em `previousTurnEvents` antes de limpar pra começar turno do próximo player.
    /// UI usa isso pra animações em tempo real das ações do próprio player.
    public var events: [DuelEvent]

    /// Snapshot do `events` do turno anterior — do OUTRO player. Populado no `endTurn`
    /// antes do handoff. UI do incoming player usa pra mostrar recap "adversário
    /// jogou X, Y, Z" quando o turno chega. Não é limpo pelas actions dentro do turno
    /// atual — só é sobrescrito no próximo `endTurn`.
    public var previousTurnEvents: [DuelEvent]

    /// **Fase 9**: metadata do match — ratings congelados no início pra cálculo
    /// determinístico de ELO no fim (ambos os players chegam no mesmo delta
    /// sem servidor central). Optional pra backward compat com states Fase 8.
    /// `RatingStore` no client é responsável por preencher e ler.
    public var matchMetadata: DuelMatchMetadata?

    public init(
        playerA: DuelPlayerState,
        playerB: DuelPlayerState,
        firstToPlay: String
    ) {
        precondition(playerA.playerID != playerB.playerID,
                     "Player IDs precisam ser distintos")
        precondition(firstToPlay == playerA.playerID || firstToPlay == playerB.playerID,
                     "firstToPlay precisa ser um dos dois players")

        self.version = DuelState.currentVersion
        self.phase = .notStarted
        self.turn = 0
        self.playerA = playerA
        self.playerB = playerB
        self.activePlayerID = firstToPlay
        self.firstToPlayID = firstToPlay
        self.events = []
        self.previousTurnEvents = []
        self.matchMetadata = nil
    }

    // MARK: - Queries

    /// O player que está jogando agora.
    public var activePlayer: DuelPlayerState {
        activePlayerID == playerA.playerID ? playerA : playerB
    }

    /// O player que está esperando sua vez.
    public var waitingPlayer: DuelPlayerState {
        activePlayerID == playerA.playerID ? playerB : playerA
    }

    /// Retorna o `DuelPlayerState` por ID, ou nil se não encontrado.
    public func player(withID id: String) -> DuelPlayerState? {
        if playerA.playerID == id { return playerA }
        if playerB.playerID == id { return playerB }
        return nil
    }

    /// ID do oponente do player passado.
    public func opponentID(of playerID: String) -> String? {
        if playerA.playerID == playerID { return playerB.playerID }
        if playerB.playerID == playerID { return playerA.playerID }
        return nil
    }

    public var isDuelOver: Bool {
        switch phase {
        case .victory, .forfeit: return true
        default: return false
        }
    }

    public var winnerID: String? {
        switch phase {
        case .victory(let id): return id
        case .forfeit(let loserID):
            return opponentID(of: loserID)
        default: return nil
        }
    }
}


/// Fase do duelo.
/// `.notStarted` → `.awaitingOpponentDeck` → `.active` → `.victory`/`.forfeit`.
///
/// **`.notStarted`** é a fase inicial default de `DuelState.init` (usado por
/// testes ou setups manuais). Fluxo Game Center pula direto pra
/// `.awaitingOpponentDeck` via `DuelFactory.createHostedDuel`.
///
/// **`.awaitingOpponentDeck`**: Alice criou o match com seu deck; Bob precisa
/// submeter o dele via `DuelAction.submitOpponentDeck`. `activePlayerID` é Bob
/// nessa fase — quem precisa agir. Assim que ele submete, engine embaralha
/// ambos os decks, saca mãos e transita pra `.active`.
public enum DuelPhase: Equatable, Codable {
    case notStarted
    case awaitingOpponentDeck
    case active
    /// Duelo terminou porque o oponente foi derrotado (HP ou Moral a 0).
    case victory(winnerID: String)
    /// Duelo terminou porque um dos players desistiu.
    case forfeit(loserID: String)
}
