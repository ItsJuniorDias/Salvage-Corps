//
//  DuelMatchStore.swift
//  Salvage Corps
//
//  @Observable wrapper de UM GKTurnBasedMatch em andamento.
//  Responsável por:
//    - Decodificar DuelState do matchData
//    - Se matchData vazio (match novo), criar DuelState inicial via DuelFactory
//    - Aplicar DuelActions localmente (via DuelEngine)
//    - Serializar state e chamar match.saveCurrentTurn ou match.endTurn na Apple
//    - Reagir a turn events pra recarregar state quando oponente jogar
//

import Foundation
import GameKit
import Observation
import SalvageCore

@Observable
final class DuelMatchStore {

    /// O match GameKit sendo gerenciado.
    private(set) var match: GKTurnBasedMatch

    /// Estado do duelo. Nil quando ainda estamos carregando/decodificando.
    private(set) var duelState: DuelState?

    /// Erro genérico da última operação (load, save, endTurn). UI mostra se relevante.
    private(set) var lastError: Error?

    /// True enquanto uma operação async (encode + save) está em curso.
    private(set) var isSaving: Bool = false

    /// **Fase 9**: resultado da última aplicação de rating desse match. Setado
    /// quando o duelo termina e o RatingStore aceita o delta. UI usa pra
    /// mostrar "1000 → 1032 (+32)" no endgame overlay. Nil se ainda não
    /// terminou, ou se já foi processado antes (idempotência).
    private(set) var lastRatingResult: RatingStore.DuelResultApplication?

    private var observer: NSObjectProtocol?

    init(match: GKTurnBasedMatch) {
        self.match = match

        // Reage a turn events do MESMO match — se oponente jogou e o Apple push chegou,
        // esse observer recarrega o state.
        observer = NotificationCenter.default.addObserver(
            forName: .scGCTurnEvent,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self,
                  let updatedMatch = notif.object as? GKTurnBasedMatch,
                  updatedMatch.matchID == self.match.matchID
            else { return }
            self.match = updatedMatch
            self.loadState()
        }

        loadState()
    }

    /// **Fase 9**: Se o `duelState` atual tá em phase de fim (.victory ou .forfeit)
    /// E tem metadata válido com ratings congelados, aplica o delta ELO no
    /// RatingStore. Idempotente via matchID — chamar múltiplas vezes é seguro.
    ///
    /// Deve ser chamado após qualquer `self.duelState = X` que possa ter
    /// mudado a phase.
    private func applyRatingIfDuelEnded() {
        guard let state = duelState else { return }
        guard let myID = GameCenterManager.shared.myGamePlayerID else { return }
        guard let metadata = state.matchMetadata, metadata.isRanked else {
            // Sem metadata ou marcado unranked — não altera rating
            return
        }

        // Determina se eu ganhei ou perdi
        let iWon: Bool
        switch state.phase {
        case .victory(let winnerID):
            iWon = winnerID == myID
        case .forfeit(let loserID):
            iWon = loserID != myID  // Se o perdedor NÃO sou eu, eu ganhei
        default:
            return  // Duelo ainda não acabou
        }

        // Identifica meu rating congelado + do oponente
        let hostID = state.playerA.playerID
        let opponentID = state.playerB.playerID
        guard let myRatingAtStart = metadata.ratingAtStart(
            for: myID, hostID: hostID, opponentID: opponentID
        ) else {
            print("[DuelMatch] Não achou rating congelado pro playerID \(myID)")
            return
        }
        let theirID = (myID == hostID) ? opponentID : hostID
        guard let opponentRatingAtStart = metadata.ratingAtStart(
            for: theirID, hostID: hostID, opponentID: opponentID
        ) else {
            print("[DuelMatch] Não achou rating congelado pro oponente")
            return
        }

        let application = RatingStore.shared.applyDuelResult(
            matchID: match.matchID,
            myRatingAtStart: myRatingAtStart,
            opponentRatingAtStart: opponentRatingAtStart,
            iWon: iWon
        )
        if let app = application {
            self.lastRatingResult = app
            print("[DuelMatch] Rating aplicado: \(app.oldRating) → \(app.newRating) (delta \(app.delta))")

            // Fase 10: grava entrada no histórico. record() é idempotente por
            // matchID (mesmo mecanismo que RatingStore.processedMatchIDs, mas
            // separado — caso um dia queiramos limpar histórico sem zerar rating).
            let opponentName = match.participants.first { p in
                p.player?.gamePlayerID == theirID
            }?.player?.displayName ?? String(localized: "duel.player.opponent_default_name")

            MatchHistoryStore.shared.record(MatchHistoryEntry(
                matchID: match.matchID,
                opponentName: opponentName,
                opponentRatingAtStart: opponentRatingAtStart,
                iWon: iWon,
                delta: app.delta,
                myRatingAfter: app.newRating
            ))

            // Fase 11: avalia e reporta achievements pro Game Center.
            // Snapshot precisa acontecer DEPOIS que RatingStore aplicou delta
            // (currentStreak, wins, losses já refletem o novo estado).
            let me = state.playerA.playerID == myID ? state.playerA : state.playerB
            let iTookNoDamage = me.player.hp == me.player.maxHP
            let snapshot = DuelOutcomeSnapshot(
                iWon: iWon,
                myRatingAfter: RatingStore.shared.currentRating,
                opponentRatingAtStart: opponentRatingAtStart,
                myRatingAtStart: myRatingAtStart,
                iTookNoDamage: iTookNoDamage,
                totalWinsAfter: RatingStore.shared.wins,
                totalMatchesAfter: RatingStore.shared.totalMatches,
                currentStreakAfter: RatingStore.shared.currentStreak
            )
            AchievementsManager.shared.evaluateAndReport(snapshot)
        }
        // Se nil, match já processado antes — não é erro, só idempotência
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Load / decode

    /// Decodifica DuelState do matchData. Se matchData vazio, é match novo:
    /// cria state inicial via DuelFactory e salva.
    ///
    /// Fase 8: se state carregado tem `phase = .awaitingOpponentDeck` e sou eu
    /// o oponente esperado (activePlayerID), auto-submete meu deck do DeckStore.
    func loadState() {
        let data = match.matchData ?? Data()

        if data.isEmpty {
            // Match novo — inicializar
            initializeNewDuel()
            return
        }

        do {
            let decoded = try JSONDecoder().decode(DuelState.self, from: data)
            self.duelState = decoded
            self.lastError = nil
            print("[DuelMatch] Estado carregado: turn=\(decoded.turn) phase=\(decoded.phase) active=\(decoded.activePlayerID)")

            // Fase 9: se o state carregado tá em phase de fim (oponente
            // desistiu offline, ou o meu último turno matou ele antes de eu
            // ver — cenários que voltam via push), aplica delta ELO agora.
            applyRatingIfDuelEnded()

            // Fase 8: se é minha vez de submeter deck (fase de setup PvP), faz isso auto.
            autoSubmitOpponentDeckIfNeeded(state: decoded)
        } catch {
            self.lastError = error
            print("[DuelMatch] Falha ao decodificar state: \(error.localizedDescription)")
        }
    }

    private func initializeNewDuel() {
        guard let myID = GameCenterManager.shared.myGamePlayerID,
              let opponent = match.opponent,
              let opponentID = opponent.player?.gamePlayerID
        else {
            // Auto-match ainda buscando — oponente não confirmado.
            print("[DuelMatch] Oponente ainda não resolveu — aguardando")
            self.duelState = nil
            return
        }

        // Fase 8: usa deck customizado do DeckStore em vez do starter fixo.
        // createHostedDuel deixa em .awaitingOpponentDeck — oponente vai
        // submeter o dele quando abrir o match.
        let myDeck = DeckStore.shared.cardsForCurrentDuel()
        var state = DuelFactory.createHostedDuel(
            hostID: myID,
            opponentID: opponentID,
            hostDeck: myDeck,
            firstToPlay: myID  // Quem criou o match começa (após setup completar)
        )

        // Fase 9: grava rating congelado do host no metadata (opponentRating
        // vai ser 0 até Bob abrir e submeter deck).
        state.matchMetadata = DuelMatchMetadata(
            isRanked: true,  // MVP: todo match é ranked
            hostID: myID,    // Fase 10: explicita quem é o host pra clients de row
            hostRatingAtStart: RatingStore.shared.currentRating,
            opponentRatingAtStart: 0
        )

        self.duelState = state
        print("[DuelMatch] Match hosted criado: \(myID) (rating \(RatingStore.shared.currentRating)) vs \(opponentID) — aguardando oponente submeter deck")

        // IMPORTANTE: aqui NÃO chamamos startDuel. State fica em .awaitingOpponentDeck.
        // Precisa passar a vez pro oponente no GameKit pra ele receber notif.
        handOverForDeckSubmission(state: state)
    }

    /// Passa a vez pro oponente via `match.endTurn` só pra ele receber notificação
    /// e abrir o match — o `DuelState` continua em `.awaitingOpponentDeck` até ele
    /// aplicar `.submitOpponentDeck`.
    private func handOverForDeckSubmission(state: DuelState) {
        guard let opponent = match.opponent else {
            self.lastError = NSError(
                domain: "SC.DuelMatch", code: 8,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.no_opponent")]
            )
            return
        }
        guard let data = try? JSONEncoder().encode(state) else {
            self.lastError = NSError(
                domain: "SC.DuelMatch", code: 9,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.state_nil_on_save")]
            )
            return
        }
        self.isSaving = true
        match.endTurn(
            withNextParticipants: [opponent],
            turnTimeout: GKTurnTimeoutDefault,
            match: data
        ) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSaving = false
                if let error = error {
                    self.lastError = error
                    print("[DuelMatch] Falha ao passar vez pra deck submission: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Se o state tá em `.awaitingOpponentDeck` E eu sou quem precisa submeter
    /// (activePlayerID == myID), pego meu deck do DeckStore e aplico a action.
    /// Depois passa a vez pro host (que é firstToPlayID).
    ///
    /// Fase 9: também grava meu rating congelado em `matchMetadata.opponentRatingAtStart`
    /// antes de submeter — necessário pra que o cálculo ELO no fim seja
    /// consistente dos dois lados.
    private func autoSubmitOpponentDeckIfNeeded(state initialState: DuelState) {
        guard initialState.phase == .awaitingOpponentDeck else { return }
        guard let myID = GameCenterManager.shared.myGamePlayerID else { return }
        guard initialState.activePlayerID == myID else {
            // Sou o host — não devo submeter em nome do oponente
            print("[DuelMatch] Estado em setup mas sou o host — aguardando oponente")
            return
        }

        // Fase 9: injeta meu rating congelado no metadata ANTES de aplicar
        // a action. Metadata é property do state, engine ignora.
        var state = initialState
        if var metadata = state.matchMetadata {
            metadata.opponentRatingAtStart = RatingStore.shared.currentRating
            state.matchMetadata = metadata
            print("[DuelMatch] Rating congelado do oponente (eu): \(RatingStore.shared.currentRating)")
        } else {
            // Metadata ausente (state legacy Fase 8?) — cria unranked com meus valores.
            // hostID vazio porque não sabemos quem foi o creator (metadata legacy)
            state.matchMetadata = DuelMatchMetadata(
                isRanked: false,
                hostID: "",
                hostRatingAtStart: 0,
                opponentRatingAtStart: RatingStore.shared.currentRating
            )
            print("[DuelMatch] AVISO: state sem metadata (legacy?), marcando como unranked")
        }

        let myDeck = DeckStore.shared.cardsForCurrentDuel()
        print("[DuelMatch] Auto-submetendo deck de \(myDeck.count) cartas")

        switch DuelEngine.apply(.submitOpponentDeck(playerID: myID, deck: myDeck), to: state) {
        case .applied(let newState):
            self.duelState = newState
            print("[DuelMatch] Deck submetido, phase=\(newState.phase), passando vez pro host")
            // Agora activePlayerID é o firstToPlayID (host). Passa a vez.
            guard let host = match.participants.first(where: { $0.player?.gamePlayerID == newState.activePlayerID }) else {
                print("[DuelMatch] AVISO: não achou participant do firstToPlayID \(newState.activePlayerID)")
                persistCurrentState { _ in }
                return
            }
            persistAndHandOver(to: host)

        case .invalid(let reason):
            self.lastError = NSError(
                domain: "SC.DuelMatch", code: 10,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.start_failed \(reason.rawValue)")]
            )
            print("[DuelMatch] submitOpponentDeck falhou: \(reason.rawValue)")
        }
    }

    /// Persiste o `duelState` atual e passa a vez pro participant especificado.
    private func persistAndHandOver(to participant: GKTurnBasedParticipant) {
        guard let state = self.duelState else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        self.isSaving = true
        match.endTurn(
            withNextParticipants: [participant],
            turnTimeout: GKTurnTimeoutDefault,
            match: data
        ) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSaving = false
                if let error = error {
                    self.lastError = error
                    print("[DuelMatch] Falha ao passar vez após submeter deck: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Actions

    /// Aplica uma DuelAction local + salva no matchData (mas NÃO passa a vez).
    /// Use pra .playCard — jogador continua no turno dele até chamar endTurnHandingOver.
    func dispatch(_ action: DuelAction, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard var state = duelState else {
            completion?(.failure(NSError(
                domain: "SC.DuelMatch", code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.state_not_loaded")]
            )))
            return
        }

        let result = DuelEngine.apply(action, to: state)
        switch result {
        case .invalid(let reason):
            let err = NSError(
                domain: "SC.DuelMatch", code: 3,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.invalid_action \(reason.rawValue)")]
            )
            completion?(.failure(err))
        case .applied(let newState):
            state = newState
            self.duelState = state
            // Fase 9: se essa action terminou o duelo (dano letal na última carta), aplica delta ELO.
            applyRatingIfDuelEnded()
            persistCurrentState(completion: completion)
        }
    }

    /// Aplica .endTurn e passa a vez ao adversário via GKTurnBasedMatch.endTurn.
    /// Depois dessa chamada, `match.isMyTurn == false` e o oponente recebe push.
    func endTurnHandingOver(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let myID = GameCenterManager.shared.myGamePlayerID else {
            completion?(.failure(NSError(
                domain: "SC.DuelMatch", code: 4,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.no_player_id")]
            )))
            return
        }

        // Aplica endTurn no DuelEngine (que também faz o handoff interno de skip, se aplicável)
        guard let currentState = duelState else {
            completion?(.failure(NSError(
                domain: "SC.DuelMatch", code: 5,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.state_not_loaded")]
            )))
            return
        }

        let engineResult = DuelEngine.apply(.endTurn(playerID: myID), to: currentState)
        var newState: DuelState
        switch engineResult {
        case .invalid(let reason):
            let err = NSError(
                domain: "SC.DuelMatch", code: 6,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.end_turn_failed \(reason.rawValue)")]
            )
            completion?(.failure(err))
            return
        case .applied(let s):
            newState = s
        }

        self.duelState = newState

        // Se o duelo terminou (vitória/derrota nesse turno), finaliza o match.
        if newState.isDuelOver {
            // Fase 9: aplica delta ELO antes de finalizar (endTurn pode causar
            // fatigue damage letal ou skip loop terminando o duelo).
            applyRatingIfDuelEnded()
            finalizeMatch(with: newState, completion: completion)
            return
        }

        // Edge case: se o oponente tinha `.skipNextTurn` stacks, o DuelEngine já
        // processou o skip automaticamente e devolveu a vez pra MIM. Nesse caso NÃO
        // passamos a vez pro oponente no GameKit — usamos saveCurrentTurn pra manter
        // minha vez (o oponente não teria nada pra fazer se fosse notificado).
        if newState.activePlayerID == myID {
            print("[DuelMatch] endTurn com skip auto-processado — mantendo turno")
            persistCurrentState(completion: completion)
            return
        }

        // Fluxo normal: nomeia oponente como próximo participante
        guard let opponent = match.opponent else {
            completion?(.failure(NSError(
                domain: "SC.DuelMatch", code: 7,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.no_opponent")]
            )))
            return
        }

        // Encoda + endTurn na Apple
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(newState)
        } catch {
            completion?(.failure(error))
            return
        }

        isSaving = true
        // turnTimeout: GKTurnTimeoutDefault (7 dias) — Apple pode auto-forfeitar se
        // o oponente não jogar. Bom pra evitar matches zumbis.
        match.endTurn(
            withNextParticipants: [opponent],
            turnTimeout: GKTurnTimeoutDefault,
            match: encoded
        ) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSaving = false
                if let error {
                    self?.lastError = error
                    print("[DuelMatch] endTurn error: \(error.localizedDescription)")
                    completion?(.failure(error))
                } else {
                    print("[DuelMatch] endTurn enviado — vez passada pro oponente")
                    completion?(.success(()))
                }
            }
        }
    }

    /// Player desiste do match. Aplica DuelAction.forfeit no engine + endMatchInTurn na Apple.
    func forfeit(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let myID = GameCenterManager.shared.myGamePlayerID else {
            completion?(.failure(NSError(
                domain: "SC.DuelMatch", code: 8,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.no_player_id")]
            )))
            return
        }
        guard var state = duelState else {
            // Sem state ainda — só usa a API da Apple pra sair do match diretamente.
            resignWithoutState(completion: completion)
            return
        }

        // Aplica forfeit no engine (marca phase = .forfeit)
        if case .applied(let s) = DuelEngine.apply(.forfeit(playerID: myID), to: state) {
            state = s
            self.duelState = state
            // Fase 9: aplica delta ELO (perdeu por desistência).
            applyRatingIfDuelEnded()
        }

        finalizeMatch(with: state, completion: completion)
    }

    // MARK: - Internal helpers

    /// Salva o state atual no matchData SEM passar a vez (saveCurrentTurn).
    private func persistCurrentState(completion: ((Result<Void, Error>) -> Void)?) {
        guard let state = duelState else {
            completion?(.failure(NSError(
                domain: "SC.DuelMatch", code: 9,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.state_nil_on_save")]
            )))
            return
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(state)
        } catch {
            completion?(.failure(error))
            return
        }

        isSaving = true
        match.saveCurrentTurn(withMatch: data) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSaving = false
                if let error {
                    self?.lastError = error
                    print("[DuelMatch] saveCurrentTurn error: \(error.localizedDescription)")
                    completion?(.failure(error))
                } else {
                    completion?(.success(()))
                }
            }
        }
    }

    /// Finaliza o match: seta outcomes pros participants + endMatchInTurn.
    private func finalizeMatch(with state: DuelState, completion: ((Result<Void, Error>) -> Void)?) {
        guard let myID = GameCenterManager.shared.myGamePlayerID else {
            completion?(.failure(NSError(
                domain: "SC.DuelMatch", code: 10,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "duel.error.no_player_id")]
            )))
            return
        }

        // Determina outcomes por participante
        for participant in match.participants {
            guard let pid = participant.player?.gamePlayerID else {
                participant.matchOutcome = .quit
                continue
            }
            if let winnerID = state.winnerID {
                participant.matchOutcome = (pid == winnerID) ? .won : .lost
            } else {
                // Forfeit sem vencedor claro
                participant.matchOutcome = (pid == myID) ? .quit : .won
            }
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(state)
        } catch {
            completion?(.failure(error))
            return
        }

        isSaving = true
        match.endMatchInTurn(withMatch: data) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSaving = false
                if let error {
                    self?.lastError = error
                    print("[DuelMatch] endMatch error: \(error.localizedDescription)")
                    completion?(.failure(error))
                } else {
                    print("[DuelMatch] Match finalizado")
                    completion?(.success(()))
                }
            }
        }
    }

    /// Sai do match antes de ter carregado state (edge case). Usa API da Apple direto.
    private func resignWithoutState(completion: ((Result<Void, Error>) -> Void)?) {
        isSaving = true
        // Se é minha vez, uso resignForNextParticipant (Apple lida com forfeit)
        if match.isMyTurn {
            let opp = match.opponent
            if let opp {
                opp.matchOutcome = .won
            }
            (match.currentParticipant ?? match.participants.first)?.matchOutcome = .quit
            match.endMatchInTurn(withMatch: match.matchData ?? Data()) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isSaving = false
                    if let error { completion?(.failure(error)) }
                    else { completion?(.success(())) }
                }
            }
        } else {
            match.participantQuitOutOfTurn(with: .quit) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isSaving = false
                    if let error { completion?(.failure(error)) }
                    else { completion?(.success(())) }
                }
            }
        }
    }
}
