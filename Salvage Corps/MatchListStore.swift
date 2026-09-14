//
//  MatchListStore.swift
//  Salvage Corps
//
//  @Observable store que mantém a lista de matches turn-based ativos do
//  local player. Recarrega automaticamente quando GameCenterManager publica
//  `.scGCTurnEvent` ou `.scGCMatchEnded`.
//

import Foundation
import GameKit
import Observation
import SalvageCore

@Observable
final class MatchListStore {

    private(set) var matches: [GKTurnBasedMatch] = []
    private(set) var isLoading: Bool = false
    private(set) var lastError: Error?

    /// Timestamp do último refresh — útil pra UI mostrar "atualizado agora".
    private(set) var lastRefreshDate: Date?

    /// **Fase 10**: cache de metadata decodificado dos matches. Chave = matchID.
    /// Populado sob demanda via `metadata(for:)`. Evita re-decodificar o state
    /// inteiro a cada render de row.
    private var metadataCache: [String: DuelMatchMetadata] = [:]

    private var observers: [NSObjectProtocol] = []

    init() {
        // Reage a turn events + match ended pra recarregar automaticamente.
        // O guard weak self evita retain cycle com NotificationCenter.
        let notifs: [Notification.Name] = [.scGCTurnEvent, .scGCMatchEnded, .scGCAuthChanged]
        for name in notifs {
            let obs = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
            observers.append(obs)
        }
    }

    deinit {
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Load

    /// Recarrega a lista de matches do Game Center. Async.
    /// Se não autenticado, limpa a lista e retorna sem erro.
    func refresh() {
        guard GameCenterManager.shared.isAuthenticated else {
            matches = []
            lastError = nil
            isLoading = false
            return
        }

        isLoading = true
        GKTurnBasedMatch.loadMatches { [weak self] loaded, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.lastRefreshDate = Date()

                if let error {
                    self.lastError = error
                    print("[MatchList] Load error: \(error.localizedDescription)")
                    return
                }

                self.lastError = nil
                self.matches = (loaded ?? []).sorted { a, b in
                    // Mais recentes primeiro. `creationDate` (não deprecated).
                    (a.creationDate) > (b.creationDate)
                }

                // Invalida entradas do cache pra matches que sumiram (removidos)
                let liveIDs = Set(self.matches.map { $0.matchID })
                self.metadataCache = self.metadataCache.filter { liveIDs.contains($0.key) }

                print("[MatchList] Carregou \(self.matches.count) match(es)")
            }
        }
    }

    // MARK: - Metadata cache (Fase 10)

    /// Retorna o `DuelMatchMetadata` de um match, decodificando lazy e cacheando.
    /// Se o matchData é vazio (novo match) ou state não tem metadata, retorna nil.
    /// Custa uma decodificação por match na primeira chamada; barato depois.
    func metadata(for match: GKTurnBasedMatch) -> DuelMatchMetadata? {
        if let cached = metadataCache[match.matchID] {
            return cached
        }
        guard let data = match.matchData, !data.isEmpty,
              let state = try? JSONDecoder().decode(DuelState.self, from: data),
              let meta = state.matchMetadata else {
            return nil
        }
        metadataCache[match.matchID] = meta
        return meta
    }

    // MARK: - Remove match (delete/forfeit da lista MY DUELS)

    /// Remove um match da lista de MY DUELS. Comportamento depende do
    /// status atual:
    ///
    ///  1. `.ended` → chama `match.remove(...)` (só remove nossa view,
    ///     opponent também precisa remover sua)
    ///  2. `.open` E é MINHA vez → `match.participantQuitInTurn(...)` —
    ///     concede vitória ao opponent + remove da nossa lista
    ///  3. `.open` E NÃO é minha vez → `match.participantQuitOutOfTurn(...)` —
    ///     concede vitória ao opponent + remove da nossa lista
    ///  4. `.matching` → `match.remove(...)` (nunca engatou, seguro remover)
    ///
    /// Após completar, chama `refresh()` pra tirar da lista visível.
    /// Se der erro, atualiza `lastError` mas continua (usuário vê no UI).
    func remove(match: GKTurnBasedMatch, completion: (() -> Void)? = nil) {
        let matchID = match.matchID
        print("[MatchList] remove requested: \(matchID) status=\(match.status.rawValue)")

        let onDone: (Error?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[MatchList] ✗ remove failed for \(matchID): \(error.localizedDescription)")
                    self?.lastError = error
                } else {
                    print("[MatchList] ✓ removed \(matchID)")
                    // Remove imediatamente da lista local pra feedback instantâneo
                    // (o refresh confirma depois com dados frescos do GC)
                    self?.matches.removeAll { $0.matchID == matchID }
                    self?.metadataCache.removeValue(forKey: matchID)
                }
                self?.refresh()
                completion?()
            }
        }

        switch match.status {
        case .ended, .matching, .unknown:
            match.remove(completionHandler: onDone)

        case .open:
            // Match ativo — desistir concede vitória ao opponent
            let nextParticipants = match.participants.filter { $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID }
            // Set outcomes: eu perco, opponent(s) ganha
            for p in match.participants {
                if p.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID {
                    p.matchOutcome = .quit
                } else {
                    p.matchOutcome = .won
                }
            }

            if match.isMyTurn {
                // Minha vez — quitInTurn passa outcome + limpa
                match.participantQuitInTurn(
                    with: .quit,
                    nextParticipants: nextParticipants,
                    turnTimeout: GKTurnTimeoutDefault,
                    match: match.matchData ?? Data(),
                    completionHandler: onDone
                )
            } else {
                // Vez do opponent — quitOutOfTurn é mais simples
                match.participantQuitOutOfTurn(
                    with: .quit,
                    withCompletionHandler: onDone
                )
            }

        @unknown default:
            match.remove(completionHandler: onDone)
        }
    }
}


// MARK: - Helpers de status pra UI

extension GKTurnBasedMatch {

    /// True se é a vez do local player agora.
    var isMyTurn: Bool {
        guard let currentID = currentParticipant?.player?.gamePlayerID,
              let myID = GKLocalPlayer.local.isAuthenticated
                ? GKLocalPlayer.local.gamePlayerID : nil
        else { return false }
        return currentID == myID
    }

    /// Retorna o participante oponente (o não-local).
    var opponent: GKTurnBasedParticipant? {
        guard GKLocalPlayer.local.isAuthenticated else { return nil }
        let myID = GKLocalPlayer.local.gamePlayerID
        return participants.first { $0.player?.gamePlayerID != myID }
    }

    /// Label curto pra UI: "Sua vez", "Vez de <name>", "Encerrado", etc. Localizado.
    var shortStatusLabel: String {
        switch status {
        case .open:
            if isMyTurn { return String(localized: "duel.status.your_turn") }
            if let opp = opponent?.player?.displayName {
                return String(localized: "duel.status.opponent_turn \(opp)")
            }
            return String(localized: "duel.status.waiting_opponent")
        case .matching:
            return String(localized: "duel.status.matchmaking")
        case .ended:
            return String(localized: "duel.status.ended")
        case .unknown:
            return String(localized: "duel.status.unknown")
        @unknown default:
            return String(localized: "duel.status.unknown")
        }
    }
}
