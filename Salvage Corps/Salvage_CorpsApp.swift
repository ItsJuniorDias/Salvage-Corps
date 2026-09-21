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
        // Build do itch.io (Developer ID) não tem Game Center nem APNs —
        // ambos exigem distribuição via App Store. Duelos ficam ocultos.
        #if !ITCH
        GameCenterManager.shared.authenticate()
        // Consulta status atual de push. Se já autorizado (session anterior),
        // re-registra com APNs. Se não autorizado, NÃO pede aqui — pedimos
        // contextualmente no DuelsMenuView quando player entra no PVP.
        PushNotificationsManager.shared.checkAuthorization()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                    UIScale.shared.update(for: size)
                }
                #if targetEnvironment(macCatalyst)
                .background(MacWindowConfigurator())
                #endif
        }
    }
}

#if targetEnvironment(macCatalyst)
/// Ajusta a janela do Mac: tamanho mínimo que mantém o layout legível e
/// barra de título escondida pra arte ocupar a janela toda.
private struct MacWindowConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { WindowProbe() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class WindowProbe: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene else { return }
            scene.sizeRestrictions?.minimumSize = CGSize(width: 960, height: 600)
            if let titlebar = scene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbar = nil
            }
        }
    }
}
#endif

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
