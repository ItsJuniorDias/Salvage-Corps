//
//  NotificationsManager.swift
//  Salvage Corps
//
//  Fase 11: pede permissão pra notificações locais/remotas. Game Center
//  Turn-Based envia push automático quando é sua vez, MAS iOS bloqueia
//  se o app nunca pediu permissão. Esse manager resolve isso.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationsManager {

    static let shared = NotificationsManager()

    private init() {}

    /// Status atual de autorização. Não faz request — só lê.
    /// Async porque UNUserNotificationCenter API é assíncrona.
    func currentStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// Requisita permissão se ainda não decidido. Se já negado ou já concedido,
    /// não faz nada (respeitando escolha do user — não spammar).
    ///
    /// Chamar APÓS auth Game Center bem-sucedida — é o momento de contexto
    /// perfeito: user acabou de conectar num sistema social e faz sentido
    /// pedir pra notificar quando algo acontece.
    ///
    /// Se conceder, também registra pra remote notifications (Game Center
    /// usa APNs por baixo pra push cross-device).
    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else {
                print("[Notifications] Status já definido: \(settings.authorizationStatus.rawValue) — pulando request")
                return
            }
            self?.requestAuthorization()
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error = error {
                print("[Notifications] Erro no request: \(error.localizedDescription)")
                return
            }

            if granted {
                print("[Notifications] Permissão concedida — registrando pra remote")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("[Notifications] Permissão negada pelo user")
            }
        }
    }
}
