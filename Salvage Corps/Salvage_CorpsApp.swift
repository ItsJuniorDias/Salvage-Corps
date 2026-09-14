//
//  Salvage_CorpsApp.swift
//  Salvage Corps
//

import SwiftUI
import UIKit

@main
struct Salvage_CorpsApp: App {

    // AppDelegate adapter — necessário APENAS pra hookar callbacks do APNs
    // (didRegisterForRemoteNotifications). SwiftUI @main puro não expõe esses.
    // Mantém tudo o mais SwiftUI-native — só delega pro PushNotificationsManager.
    @UIApplicationDelegateAdaptor(SalvageAppDelegate.self) var appDelegate

    init() {
        // Warmup do AudioManager (singleton). Config do session acontece aqui.
        _ = AudioManager.shared
        // Carrega catálogo de eventos localizado e injeta no core.
        // Se falhar, EventCatalog usa embedded pt-BR (sem crash).
        EventStore.loadAndInject()
        // Carrega textos de terminal choice + endings pra views app-side.
        TerminalTextStore.loadForCurrentLanguage()
        EndingTextStore.loadForCurrentLanguage()
        // Dispara auth do Game Center pra habilitar Duelos PvP.
        // Apple resolve async — RootView reflete estado via GameCenterManager.
        GameCenterManager.shared.authenticate()
        // Consulta status atual de push. Se já autorizado (session anterior),
        // re-registra com APNs. Se não autorizado, NÃO pede aqui — pedimos
        // contextualmente no DuelsMenuView quando player entra no PVP.
        PushNotificationsManager.shared.checkAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - AppDelegate adapter (APNs hooks apenas)

/// Delegate mínimo — só existe pra receber os callbacks do APNs registration
/// que SwiftUI @main não expõe. Todo o resto continua SwiftUI-native.
final class SalvageAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    /// APNs completou registro — passa token pro PushNotificationsManager.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationsManager.shared.handleDidRegister(deviceToken: deviceToken)
    }

    /// APNs falhou (offline, cert inválido, etc). Não bloqueia app.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationsManager.shared.handleDidFailToRegister(error: error)
    }
}
