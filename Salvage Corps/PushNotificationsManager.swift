//
//  PushNotificationsManager.swift
//  Salvage Corps
//
//  Gerencia autorização + registro pra push notifications remotas (APNs).
//
//  ARQUITETURA:
//  Game Center Turn-Based envia push notifications AUTOMATICAMENTE quando:
//    - Alguém joga o turno e passa pra você
//    - Alguém convida você pra um match
//    - Um match termina
//
//  NÃO precisamos de:
//    - Servidor APNs próprio
//    - Backend gerenciando push tokens
//    - Payload customizado (Game Center controla o texto)
//
//  Precisamos apenas de:
//    1. Push Notifications capability habilitada no Xcode (feito no
//       `.entitlements` — aps-environment = development/production)
//    2. Push Notifications habilitada no App ID no Apple Developer Portal
//    3. Pedir permissão ao usuário (UNUserNotificationCenter)
//    4. Registrar o device com APNs (UIApplication.registerForRemoteNotifications)
//    5. Tratar notification recebida (foreground OU background)
//
//  Ver `PUSH_NOTIFICATIONS_SETUP.md` na raiz do projeto pra passos
//  Apple Developer Portal.
//

import Foundation
import UIKit
import UserNotifications
import Observation

@Observable
final class PushNotificationsManager: NSObject {

    static let shared = PushNotificationsManager()

    // MARK: - State (observável pra UI)

    /// Status atual da autorização — atualizado após checkAuthorization().
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// True se o device registrou com APNs com sucesso.
    private(set) var isRegisteredWithAPNs: Bool = false

    /// Device token (pra debug/analytics). Não usamos pra push customizado.
    private(set) var deviceTokenHex: String?

    /// Último erro (registro APNs falhou, etc). UI pode mostrar.
    private(set) var lastError: String?

    /// Match ID que o usuário tocou na notification (fora do app) — a UI
    /// pode ler + navegar direto pra ele. Setar pra nil após consumir.
    var pendingMatchID: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Public API

    /// Consulta status atual sem pedir permissão. Chamar no onAppear das
    /// telas que dependem de push (ex: Duels) pra decidir se mostra prompt.
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                print("[Push] authorization status = \(settings.authorizationStatus.rawValue)")

                // Se já autorizado, garante que estamos registrados no APNs
                // (pode acontecer de estar autorizado mas registro APNs ter
                // falhado — network flaky, etc). Registrar é idempotente.
                if settings.authorizationStatus == .authorized {
                    self?.registerWithAPNs()
                }
            }
        }
    }

    /// Pede permissão ao usuário. Só chamar em contexto claro (ex:
    /// primeiro acesso ao Duels), NÃO no onboarding — user rejeita rápido
    /// quando não entende por quê.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[Push] ✗ requestAuthorization failed: \(error.localizedDescription)")
                    self?.lastError = error.localizedDescription
                }

                print("[Push] authorization granted = \(granted)")
                self?.authorizationStatus = granted ? .authorized : .denied

                if granted {
                    self?.registerWithAPNs()
                }
                completion(granted)
            }
        }
    }

    /// Registra o device com APNs. Só faz sentido chamar após autorização
    /// concedida. Idempotente. Callback via UIApplicationDelegate ou via
    /// notifications abaixo (`didRegister…`).
    func registerWithAPNs() {
        print("[Push] registering with APNs...")
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - APNs callbacks (chamados pelo AppDelegate/App)

    /// Chamar do `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    /// Como usamos SwiftUI @main sem AppDelegate, o hook é feito via
    /// NSNotification `.pnDidRegisterAPNs` publicada abaixo.
    func handleDidRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        DispatchQueue.main.async { [weak self] in
            self?.deviceTokenHex = hex
            self?.isRegisteredWithAPNs = true
            self?.lastError = nil
            print("[Push] ✓ registered with APNs — token: \(String(hex.prefix(12)))...")
        }
    }

    /// Chamar do `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.
    func handleDidFailToRegister(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isRegisteredWithAPNs = false
            self?.lastError = error.localizedDescription
            print("[Push] ✗ APNs registration failed: \(error.localizedDescription)")
        }
    }

    /// Abre Settings do app — usado quando player negou permissão e
    /// depois muda de ideia. Só há esse caminho (Apple não permite
    /// re-perguntar no app).
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationsManager: UNUserNotificationCenterDelegate {

    /// Chamado quando notification chega com app EM FOREGROUND.
    /// Default seria não mostrar nada — retornamos `.banner + .sound`
    /// pra o usuário ver mesmo com app aberto (aparece como toast top).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        print("[Push] foreground notification: \(content.title) - \(content.body)")
        completionHandler([.banner, .sound, .badge])
    }

    /// Chamado quando usuário toca a notification (app estava background
    /// ou fechado). Tenta extrair matchID pra RootView navegar direto.
    ///
    /// Game Center payload tem estrutura estável mas não documentada:
    ///   userInfo["gameCenter"] = { "matchID": "..." }  (turn events)
    /// Se não conseguir extrair, RootView simplesmente abre Duels menu.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[Push] user tapped notification: userInfo = \(userInfo)")

        // Tenta extrair matchID de payloads conhecidos do Game Center
        if let gc = userInfo["gameCenter"] as? [String: Any],
           let matchID = gc["matchID"] as? String {
            print("[Push] extracted matchID = \(matchID)")
            DispatchQueue.main.async { [weak self] in
                self?.pendingMatchID = matchID
                NotificationCenter.default.post(
                    name: .pnDidTapMatchNotification,
                    object: matchID
                )
            }
        } else {
            print("[Push] no matchID in payload — will route to Duels menu")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .pnDidTapMatchNotification,
                    object: nil
                )
            }
        }

        completionHandler()
    }
}

// MARK: - Notification names

extension Notification.Name {
    /// Publicada quando usuário toca notification remota (turn event / invite).
    /// `object` = matchID (String) se extraível, senão nil.
    static let pnDidTapMatchNotification = Notification.Name("pnDidTapMatchNotification")
}
