//
//  LobbyView.swift
//  Salvage Corps
//
//  Tela custom de matchmaking. Substitui o GKTurnBasedMatchmakerViewController
//  nativo (com tabs Play Now/Friends) por uma UX própria de "procurando
//  adversário" — mais integrada visualmente com o resto do app.
//
//  Fluxo:
//    1. onAppear → chama MatchmakerPresenter.findMatchProgrammatically()
//    2. Se retorna match COMPLETO (opponent já confirmado):
//       → abre DuelMatchStore + navega pra tela de combate
//    3. Se retorna match INCOMPLETO (só nós, aguardando alguém entrar):
//       → mantém tela de wait com spinner + timer
//       → escuta `.scGCTurnEvent` — quando opponent entrar, dispara automático
//    4. Após 45s sem match completo → oferece "Convidar amigo" como fallback
//    5. Botão CANCELAR a qualquer momento → remove match do pool + volta
//
//  IMPORTANTE — LIMITAÇÃO INERENTE:
//  Mesmo com UX perfeita, o matchmaking pool da Apple depende de ESCALA.
//  Salvage Corps ainda não tem base grande — se ninguém está no pool no
//  mesmo momento, esperar não vai fazer aparecer. A tela de fallback pra
//  invite amigo cobre esse caso.
//

import SwiftUI
import GameKit

struct LobbyView: View {

    /// Callback quando match completo é obtido — RootView usa pra navegar
    /// pra tela de combate.
    var onMatchFound: (GKTurnBasedMatch) -> Void

    /// Callback quando player cancela o lobby ou o matchmaking falha.
    var onCancel: () -> Void

    @State private var currentMatch: GKTurnBasedMatch? = nil
    @State private var elapsedSeconds: Int = 0
    @State private var lastError: String? = nil
    @State private var isSearching: Bool = false
    @State private var showFallback: Bool = false
    @State private var pulseCounter: Int = 0

    /// Segundos até mostrar o painel de fallback (invite amigo).
    /// Escolhido empiricamente: <30s parece impaciência, >60s parece
    /// esquecido. 45s é sweet spot.
    private let fallbackThresholdSeconds = 45

    var body: some View {
        ZStack {
            // Bg PVP menu — reusa asset existente
            Image("bg_pvp_menu")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )

            VStack(spacing: 24) {
                topBar

                Spacer()

                if showFallback {
                    fallbackPanel
                } else {
                    searchingPanel
                }

                Spacer()

                cancelButton
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 40)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startMatchmaking()
            startTicker()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scGCTurnEvent)) { notif in
            handleTurnEvent(notif)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("duel.lobby.title")
                .font(SalvageFont.titleXL(24))
                .foregroundStyle(SalvageColor.boneWhite)
                .tracking(6)
            Spacer()
        }
    }

    // MARK: - Searching panel (0-45s)

    private var searchingPanel: some View {
        VStack(spacing: 20) {
            // Spinner com pulse dourado
            ZStack {
                Circle()
                    .stroke(SalvageColor.boneWhite.opacity(0.08), lineWidth: 3)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(SalvageColor.energyOrange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(Double(pulseCounter) * 12))
                    .animation(.linear(duration: 0.08), value: pulseCounter)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 34))
                    .foregroundStyle(SalvageColor.energyOrange)
            }

            VStack(spacing: 6) {
                Text(currentStatusMessage)
                    .font(SalvageFont.header(13))
                    .tracking(3)
                    .foregroundStyle(SalvageColor.boneWhite.opacity(0.85))
                    .multilineTextAlignment(.center)

                Text(formattedElapsed)
                    .font(SalvageFont.number(38))
                    .foregroundStyle(SalvageColor.energyOrange)
                    .monospacedDigit()
            }

            if let err = lastError {
                Text(err)
                    .font(SalvageFont.body(10))
                    .foregroundStyle(SalvageColor.bloodAccent.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            // Dica sutil sobre pool limitado (só aparece depois de 15s pra não
            // desanimar imediatamente)
            if elapsedSeconds >= 15 {
                Text("duel.lobby.hint")
                    .font(SalvageFont.body(10))
                    .foregroundStyle(SalvageColor.boneWhite.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
            }
        }
    }

    /// Mensagem principal muda conforme o tempo — evita a mesma string
    /// hipnótica por 45s (parece travado).
    private var currentStatusMessage: LocalizedStringKey {
        switch elapsedSeconds {
        case 0..<10:  return "duel.lobby.searching"
        case 10..<25: return "duel.lobby.searching_still"
        default:      return "duel.lobby.searching_long"
        }
    }

    private var formattedElapsed: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Fallback panel (45s+)

    private var fallbackPanel: some View {
        VStack(spacing: 18) {
            Image(systemName: "hourglass")
                .font(.system(size: 44))
                .foregroundStyle(SalvageColor.scarGold.opacity(0.85))

            Text("duel.lobby.fallback_title")
                .font(SalvageFont.header(14))
                .tracking(3)
                .foregroundStyle(SalvageColor.boneWhite)
                .multilineTextAlignment(.center)

            Text("duel.lobby.fallback_body")
                .font(SalvageFont.body(11))
                .foregroundStyle(SalvageColor.boneWhite.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .lineSpacing(2)

            VStack(spacing: 10) {
                Button {
                    inviteFriend()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 14))
                        Text("duel.lobby.invite_friend")
                            .font(SalvageFont.header(12))
                            .tracking(3)
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(SalvageColor.energyOrange))
                }
                .buttonStyle(.plain)

                Button {
                    continueWaiting()
                } label: {
                    Text("duel.lobby.keep_waiting")
                        .font(SalvageFont.body(11))
                        .foregroundStyle(SalvageColor.boneWhite.opacity(0.6))
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Cancel button (sempre visível)

    private var cancelButton: some View {
        Button {
            cancel()
        } label: {
            Text("duel.lobby.cancel")
                .font(SalvageFont.label(11))
                .tracking(3)
                .foregroundStyle(SalvageColor.boneWhite.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lifecycle & actions

    private func startMatchmaking() {
        guard !isSearching else { return }
        isSearching = true
        lastError = nil

        MatchmakerPresenter.shared.findMatchProgrammatically { result in
            Task { @MainActor in
                switch result {
                case .success(let match):
                    self.currentMatch = match
                    // Se já veio COMPLETO (ambos participants com player != nil), parte
                    if isMatchComplete(match) {
                        print("[Lobby] match retornado JÁ COMPLETO — partindo pro combate")
                        self.onMatchFound(match)
                    } else {
                        print("[Lobby] match retornado INCOMPLETO — aguardando opponent entrar")
                        // Aqui a Apple continua procurando em background.
                        // O GKLocalPlayerListener vai disparar `.scGCTurnEvent`
                        // quando alguém entrar → handleTurnEvent processa.
                    }

                case .failure(let error):
                    self.lastError = error.localizedDescription
                    print("[Lobby] falhou: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startTicker() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    elapsedSeconds += 1
                    pulseCounter += 1
                    if elapsedSeconds >= fallbackThresholdSeconds && !showFallback {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showFallback = true
                        }
                    }
                }
            }
        }
    }

    private func handleTurnEvent(_ notif: Notification) {
        guard let updated = notif.object as? GKTurnBasedMatch else { return }
        // Só interessa se é do NOSSO match pendente
        guard let current = currentMatch, updated.matchID == current.matchID else { return }

        print("[Lobby] receivedTurnEvent for our match — check completeness")
        currentMatch = updated
        if isMatchComplete(updated) {
            print("[Lobby] agora está COMPLETO — partindo pro combate")
            onMatchFound(updated)
        }
    }

    private func isMatchComplete(_ match: GKTurnBasedMatch) -> Bool {
        // Completo = 2+ participants E TODOS já têm `player != nil` (não são
        // slots vazios esperando alguém).
        guard match.participants.count >= 2 else { return false }
        return match.participants.allSatisfy { $0.player != nil }
    }

    private func inviteFriend() {
        // Cancela o match programático atual antes de abrir o invite friend
        // (senão fica lingering no pool)
        if let match = currentMatch {
            MatchmakerPresenter.shared.cancelPendingMatch(match)
        }
        // Volta pro menu e chama invite — o listener vai disparar quando
        // opponent aceitar, e o match aparece na lista normalmente.
        onCancel()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            MatchmakerPresenter.shared.presentInviteFriend()
        }
    }

    private func continueWaiting() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showFallback = false
        }
    }

    private func cancel() {
        if let match = currentMatch {
            MatchmakerPresenter.shared.cancelPendingMatch(match)
        }
        onCancel()
    }
}
