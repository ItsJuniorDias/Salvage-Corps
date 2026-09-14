//
//  MatchmakerPresenter.swift
//  Salvage Corps
//
//  Apresenta o GKTurnBasedMatchmakerViewController da Apple em 2 modos:
//  - Auto-match: busca adversário aleatório no matchmaking pool global
//  - Invite friend: pula matchmaking, abre direto no picker de amigos
//
//  O resultado (match criado) chega via GKLocalPlayerListener.receivedTurnEventFor
//  no GameCenterManager — não precisa de delegate próprio no VC (iOS 14+).
//
//  ⚠️ CONHECIDO: auto-match funciona MAL em apps não-publicados / com poucos
//  jogadores porque o matchmaking pool da Apple depende de escala. Devs
//  relatam há anos que "invite funciona sempre; auto-match falha silent
//  até o app ter ~50+ jogadores ativos diários". Enquanto isso, invite é
//  o caminho recomendado. Documentado no `LIMITATIONS_AUTOMATCH.md`.
//

import Foundation
import GameKit
import UIKit

/// Singleton stateless que apresenta o VC de matchmaking do Game Center.
///
/// **Por que singleton?** Porque precisa ser NSObject retido em algum lugar
/// pro delegate do VC não virar zombie. Guardar como singleton evita
/// que o SwiftUI-side (View) tenha que reter.
final class MatchmakerPresenter: NSObject {

    static let shared = MatchmakerPresenter()

    private override init() { super.init() }

    /// Callback opcional chamado quando o usuário cancela o matchmaker.
    /// Usado pra fechar loading spinners na UI, por exemplo.
    var onCanceled: (() -> Void)?

    /// Callback opcional chamado quando o matchmaker falha.
    var onFailed: ((Error) -> Void)?

    // MARK: - Present (auto-match)

    /// Apresenta o matchmaker configurado pra 1v1 auto-match.
    /// Apple busca adversário no matchmaking pool global.
    ///
    /// ⚠️ Auto-match tem alta latência / pode falhar silent em apps novos.
    /// Se o usuário quer garantia de match agora, usar `presentInviteFriend()`.
    func presentNewMatch() {
        let ts = timestamp()
        print("[Matchmaker \(ts)] presentNewMatch() called")

        guard GameCenterManager.shared.isAuthenticated else {
            print("[Matchmaker \(ts)]   ✗ ABORT: não autenticado no Game Center")
            return
        }

        print("[Matchmaker \(ts)]   ✓ authenticated as \(GKLocalPlayer.local.displayName) (\(GKLocalPlayer.local.gamePlayerID))")

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2
        request.inviteMessage = String(localized: "duel.matchmaker.invite_message")

        print("[Matchmaker \(ts)]   config: min=\(request.minPlayers) max=\(request.maxPlayers) mode=default")

        let vc = GKTurnBasedMatchmakerViewController(matchRequest: request)
        vc.turnBasedMatchmakerDelegate = self
        vc.showExistingMatches = true  // permite abrir match ativo do mesmo VC
        // matchmakingMode = .default → VC mostra tabs "Play Now" (auto) e "Friends"

        print("[Matchmaker \(ts)]   → presenting VC (mode=default, showExisting=true)")
        GameCenterManager.presentOnRoot(vc)
    }

    // MARK: - Present (invite friend)

    /// Apresenta o matchmaker configurado pra CONVIDAR AMIGO específico.
    /// Pula tab de auto-match — abre direto no picker de amigos do Game Center.
    ///
    /// Requer iOS 15+ pra `matchmakingMode`. Antes disso cai no comportamento
    /// default (mostra ambos os tabs).
    ///
    /// **Recomendado** pra qualquer partida que você QUER acontecer agora.
    /// Bypass do matchmaking pool = zero fragilidade, invite chega por push
    /// no device do amigo instantaneamente.
    func presentInviteFriend() {
        let ts = timestamp()
        print("[Matchmaker \(ts)] presentInviteFriend() called")

        guard GameCenterManager.shared.isAuthenticated else {
            print("[Matchmaker \(ts)]   ✗ ABORT: não autenticado no Game Center")
            return
        }

        print("[Matchmaker \(ts)]   ✓ authenticated as \(GKLocalPlayer.local.displayName)")

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2
        request.inviteMessage = String(localized: "duel.matchmaker.invite_message")

        let vc = GKTurnBasedMatchmakerViewController(matchRequest: request)
        vc.turnBasedMatchmakerDelegate = self
        vc.showExistingMatches = false  // foco total: só convidar

        if #available(iOS 15.0, *) {
            vc.matchmakingMode = .inviteOnly
            print("[Matchmaker \(ts)]   config: mode=.inviteOnly (iOS 15+)")
        } else {
            print("[Matchmaker \(ts)]   config: mode=default (iOS < 15 fallback)")
        }

        print("[Matchmaker \(ts)]   → presenting VC (invite mode)")
        GameCenterManager.presentOnRoot(vc)
    }

    // MARK: - Helpers

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}


// MARK: - GKTurnBasedMatchmakerViewControllerDelegate

extension MatchmakerPresenter: GKTurnBasedMatchmakerViewControllerDelegate {

    func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        let ts = timestamp()
        print("[Matchmaker \(ts)] ⊘ CANCELED by user (dismissed VC without creating match)")
        viewController.dismiss(animated: true) { [weak self] in
            self?.onCanceled?()
        }
    }

    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController,
                                           didFailWithError error: Error) {
        let ts = timestamp()
        let nsError = error as NSError
        print("[Matchmaker \(ts)] ✗ FAILED")
        print("[Matchmaker \(ts)]   error.domain: \(nsError.domain)")
        print("[Matchmaker \(ts)]   error.code: \(nsError.code)")
        print("[Matchmaker \(ts)]   error.localizedDescription: \(error.localizedDescription)")
        print("[Matchmaker \(ts)]   error.userInfo: \(nsError.userInfo)")
        viewController.dismiss(animated: true) { [weak self] in
            self?.onFailed?(error)
        }
    }

    // NOTE: `didFind(_:)` foi DEPRECADO no iOS 15. A Apple recomenda usar
    // `GKLocalPlayerListener.player(_:receivedTurnEventFor:didBecomeActive:)`
    // pra reagir ao match criado — o VC dismisses automaticamente.
    // Portanto não implementamos didFind aqui, e o pipeline via listener é
    // o único caminho de match creation.

    // MARK: - Programmatic matchmaking (LobbyView, sem VC nativo)

    /// Faz auto-match programaticamente — SEM abrir o VC nativo do Apple.
    /// Usado pela LobbyView pra dar UX própria de "procurando adversário".
    ///
    /// Comportamento da API `GKTurnBasedMatch.find(for:)`:
    /// - Se há outro player procurando NO MESMO MOMENTO: retorna match
    ///   COMPLETO (2 participants confirmados) — pode partir pro combate direto
    /// - Se ninguém está procurando: retorna match INCOMPLETO (só nós, opponent
    ///   ainda não confirmado). Apple continua procurando em background — quando
    ///   alguém entrar, dispara evento via GKLocalPlayerListener.
    /// - Se erro (network, cancelado, etc): retorna via completion com error
    ///
    /// Callback recebe `Result<GKTurnBasedMatch, Error>` — LobbyView inspeciona
    /// o match retornado e decide o que fazer:
    ///   - `match.participants.count == 2` E ambos com `.player != nil` → completo, parte
    ///   - senão → incompleto, mantém spinner e escuta listener
    func findMatchProgrammatically(completion: @escaping (Result<GKTurnBasedMatch, Error>) -> Void) {
        let ts = timestamp()
        print("[Matchmaker \(ts)] findMatchProgrammatically() called")

        guard GameCenterManager.shared.isAuthenticated else {
            print("[Matchmaker \(ts)]   ✗ ABORT: não autenticado")
            let err = NSError(
                domain: "MatchmakerPresenter",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated with Game Center"]
            )
            completion(.failure(err))
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2
        request.inviteMessage = String(localized: "duel.matchmaker.invite_message")

        print("[Matchmaker \(ts)]   calling GKTurnBasedMatch.find(for:)...")

        GKTurnBasedMatch.find(for: request) { match, error in
            let ts2 = self.timestamp()
            if let error = error {
                let nsErr = error as NSError
                print("[Matchmaker \(ts2)] ✗ find failed: domain=\(nsErr.domain) code=\(nsErr.code) — \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let match = match else {
                print("[Matchmaker \(ts2)] ✗ find returned nil match without error")
                let err = NSError(
                    domain: "MatchmakerPresenter",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "No match returned"]
                )
                completion(.failure(err))
                return
            }

            print("[Matchmaker \(ts2)] ✓ find returned match \(match.matchID)")
            print("[Matchmaker \(ts2)]   participants: \(match.participants.count)")
            for (i, p) in match.participants.enumerated() {
                let name = p.player?.displayName ?? "(pending)"
                print("[Matchmaker \(ts2)]     [\(i)] \(name)")
            }
            completion(.success(match))
        }
    }

    /// Cancela um match em progresso (usado pelo botão CANCELAR do lobby).
    /// Chama `remove(...)` no match pra sair do pool e liberar o slot.
    /// Silent — não avisa o player se der erro (ele já está saindo).
    func cancelPendingMatch(_ match: GKTurnBasedMatch) {
        let ts = timestamp()
        print("[Matchmaker \(ts)] cancelPendingMatch: \(match.matchID)")
        match.remove { error in
            let ts2 = self.timestamp()
            if let error = error {
                print("[Matchmaker \(ts2)] ⚠ cancel/remove failed: \(error.localizedDescription)")
            } else {
                print("[Matchmaker \(ts2)] ✓ match removed successfully")
            }
        }
    }
}
