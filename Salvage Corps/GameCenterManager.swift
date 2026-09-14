//
//  GameCenterManager.swift
//  Salvage Corps
//
//  Fase 1: auth do Game Center.
//  Fase 3: listener pra turn events + matchmaker presentation helper.
//

import Foundation
import GameKit
import SwiftUI
import UIKit

/// Notification names publicadas quando o Game Center envia eventos.
/// Stores observam essas pra atualizar UI (lista de matches, match aberto, etc).
extension Notification.Name {
    /// Um match teve update — alguém jogou um turno OU você criou/entrou num match novo.
    /// `object`: o `GKTurnBasedMatch` afetado.
    static let scGCTurnEvent = Notification.Name("SC.gc.turnEvent")

    /// Um match acabou (someone won/lost/quit).
    /// `object`: o `GKTurnBasedMatch` afetado.
    static let scGCMatchEnded = Notification.Name("SC.gc.matchEnded")

    /// Estado de auth mudou. `object`: `Bool` (isAuthenticated novo).
    static let scGCAuthChanged = Notification.Name("SC.gc.authChanged")
}


/// Singleton que gerencia:
/// - Auth do Game Center (Fase 1)
/// - Registro como `GKLocalPlayerListener` pra receber turn events (Fase 3)
/// - Apresentação do `GKTurnBasedMatchmakerViewController` (Fase 3)
///
/// **Precisa ser NSObject** pra conformar `GKLocalPlayerListener`.
/// `@Observable` funciona OK com NSObject subclasses.
@Observable
final class GameCenterManager: NSObject {

    static let shared = GameCenterManager()

    /// True se o local player está autenticado no Game Center.
    private(set) var isAuthenticated: Bool = false

    /// Local player Apple ID. Nil se não autenticado.
    var localPlayer: GKLocalPlayer? {
        let lp = GKLocalPlayer.local
        return lp.isAuthenticated ? lp : nil
    }

    /// Último erro de auth. UI mostra em DuelsMenuView.
    private(set) var lastAuthError: Error?

    /// Guarda se já registramos como listener — idempotente pra evitar double-register.
    private var didRegisterListener: Bool = false

    private override init() { super.init() }

    // MARK: - Auth

    /// Dispara o fluxo de auth. Chamado no App init. Idempotente.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            guard let self else { return }

            if let error {
                self.lastAuthError = error
                self.setAuthenticated(false)
                print("[GameCenter] Auth error: \(error.localizedDescription)")
                return
            }

            if let vc {
                Self.presentOnRoot(vc)
                print("[GameCenter] Apresentando UI de auth")
                return
            }

            // Sucesso
            self.lastAuthError = nil
            self.setAuthenticated(GKLocalPlayer.local.isAuthenticated)
            print("[GameCenter] Autenticado: \(GKLocalPlayer.local.displayName) (\(GKLocalPlayer.local.gamePlayerID))")

            // Registra como listener pra receber eventos de turn-based matches.
            // Único listener por local player — chamar múltiplas vezes substitui.
            if !self.didRegisterListener {
                GKLocalPlayer.local.register(self)
                self.didRegisterListener = true
                print("[GameCenter] Listener registrado")
            }
        }
    }

    private func setAuthenticated(_ value: Bool) {
        guard isAuthenticated != value else { return }
        isAuthenticated = value
        NotificationCenter.default.post(name: .scGCAuthChanged, object: value)

        // Fase 11: quando autentica com sucesso, pede permissão pra notifs
        // (Game Center Turn-Based envia push automático — mas iOS bloqueia
        // se app nunca pediu). Também re-envia rating pro leaderboard caso
        // tenha mudado offline.
        if value {
            NotificationsManager.shared.requestAuthorizationIfNeeded()
            RatingStore.shared.forceResubmit()
        }
    }

    // MARK: - Convenience

    var displayName: String { localPlayer?.displayName ?? "" }
    var myGamePlayerID: String? { localPlayer?.gamePlayerID }

    // MARK: - Presentation helper

    /// Apresenta um VC modal no root controller da primeira scene ativa.
    /// Usado pro auth VC + pro matchmaker VC (Fase 3).
    static func presentOnRoot(_ vc: UIViewController) {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                        ?? UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene }).first,
                  let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                        ?? scene.windows.first?.rootViewController
            else {
                print("[GameCenter] Falha ao achar root VC pra apresentar")
                return
            }
            var topmost = root
            while let presented = topmost.presentedViewController {
                topmost = presented
            }
            topmost.present(vc, animated: true)
        }
    }
}


// MARK: - GKLocalPlayerListener

extension GameCenterManager: GKLocalPlayerListener {

    /// Chamado quando é a nossa vez num match (alguém jogou e passou pra nós,
    /// OU criamos um match novo, OU o app foi aberto por push notification
    /// desse match).
    ///
    /// `didBecomeActive`: true se o app foi despertado por essa notification
    /// (usuário tocou no push). Pode ser útil pra navegar direto pro match.
    func player(_ player: GKPlayer,
                receivedTurnEventFor match: GKTurnBasedMatch,
                didBecomeActive: Bool) {
        let ts = timestampLog()
        print("[GameCenter \(ts)] ▶ receivedTurnEventFor")
        print("[GameCenter \(ts)]   match.matchID: \(match.matchID)")
        print("[GameCenter \(ts)]   match.status: \(matchStatusDescription(match.status))")
        print("[GameCenter \(ts)]   didBecomeActive: \(didBecomeActive)")
        print("[GameCenter \(ts)]   participants: \(match.participants.count)")
        for (i, p) in match.participants.enumerated() {
            let name = p.player?.displayName ?? "(no player yet — awaiting)"
            let status = participantStatusDescription(p.status)
            print("[GameCenter \(ts)]     [\(i)] \(name) — status: \(status)")
        }
        print("[GameCenter \(ts)]   currentParticipant: \(match.currentParticipant?.player?.displayName ?? "nil")")
        NotificationCenter.default.post(name: .scGCTurnEvent, object: match)
    }

    /// Match terminou (alguém venceu, alguém desistiu, timeout, etc).
    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        let ts = timestampLog()
        print("[GameCenter \(ts)] ■ matchEnded: \(match.matchID)")
        NotificationCenter.default.post(name: .scGCMatchEnded, object: match)
    }

    // MARK: Debug helpers (privados nessa extension)

    private func timestampLog() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func matchStatusDescription(_ status: GKTurnBasedMatch.Status) -> String {
        switch status {
        case .unknown: return "unknown"
        case .open: return "open (active)"
        case .ended: return "ended"
        case .matching: return "matching (searching for players)"
        @unknown default: return "unknown-\(status.rawValue)"
        }
    }

    private func participantStatusDescription(_ status: GKTurnBasedParticipant.Status) -> String {
        switch status {
        case .unknown: return "unknown"
        case .invited: return "invited (pending accept)"
        case .declined: return "declined"
        case .matching: return "matching (auto-match searching)"
        case .active: return "active (playing)"
        case .done: return "done"
        @unknown default: return "unknown-\(status.rawValue)"
        }
    }
}
