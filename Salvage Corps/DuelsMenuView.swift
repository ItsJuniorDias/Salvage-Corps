//
//  DuelsMenuView.swift
//  Salvage Corps
//
//  Fase 3: hub do modo Duelos. Reformulado na Fase 10.5 pra dashboard
//  2-coluna (landscape-only) — rating hero à esquerda, matches ativos à direita,
//  ações secundárias em row footer. Aproveita landscape em vez de empilhar
//  cards em coluna estreita.
//

import SwiftUI
import GameKit
import Pow
import UIKit
import SalvageCore

struct DuelsMenuView: View {

    @Bindable var gameCenter: GameCenterManager
    @Bindable var matchList: MatchListStore
    @Bindable var ratingStore: RatingStore

    /// Manager de push notifications — banner discreto oferece pedir permissão
    /// se ainda não decidiu, OU abrir Settings se player negou antes.
    @Bindable private var pushManager = PushNotificationsManager.shared

    var onOpenMatch: (GKTurnBasedMatch) -> Void
    var onOpenDeckBuilder: () -> Void
    var onOpenHistory: () -> Void
    var onBack: () -> Void

    /// Abre a nova LobbyView custom em vez do VC nativo do Apple.
    /// UX de "procurando adversário..." integrada ao app.
    var onOpenLobby: () -> Void = {}

    /// Match selecionado pra remoção (via context menu / long-press).
    /// Quando != nil, dispara o confirmationDialog. Setar pra nil descarta.
    @State private var matchPendingRemoval: GKTurnBasedMatch? = nil

    var body: some View {
        ZStack {
            Image("bg_pvp_menu")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.92), Color.black.opacity(0.75)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 4)

                if gameCenter.isAuthenticated {
                    dashboardBody
                } else {
                    unauthenticatedBody
                }
            }
            // Constrange o container à largura da tela — sem isso, se algum
            // child interno (ex: footer com 5 botões) precisa de mais espaço
            // que o disponível, o VStack extravasa horizontalmente e MY DUELS
            // vaza pra direita da tela.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if gameCenter.isAuthenticated {
                matchList.refresh()
            }
            // Re-checa status de push. Player pode ter mudado em Settings
            // desde a última vez que abriu — atualiza banner (bindable).
            pushManager.checkAuthorization()
        }
        // ConfirmationDialog de remoção do match — texto muda conforme
        // status do match (ended = só remove; ativo = forfeit + remove).
        .confirmationDialog(
            confirmationTitle(for: matchPendingRemoval),
            isPresented: Binding(
                get: { matchPendingRemoval != nil },
                set: { if !$0 { matchPendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: matchPendingRemoval
        ) { match in
            Button(role: .destructive) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                matchList.remove(match: match)
                matchPendingRemoval = nil
            } label: {
                Text(confirmActionKey(for: match))
            }
            Button("common.cancel", role: .cancel) {
                matchPendingRemoval = nil
            }
        } message: { match in
            Text(confirmationMessage(for: match))
        }
    }

    /// Título do dialog — muda conforme status.
    private func confirmationTitle(for match: GKTurnBasedMatch?) -> LocalizedStringKey {
        guard let match = match else { return "" }
        return match.status == .ended
            ? "duel.remove.title_ended"
            : "duel.remove.title_active"
    }

    /// Mensagem body do dialog.
    private func confirmationMessage(for match: GKTurnBasedMatch) -> LocalizedStringKey {
        return match.status == .ended
            ? "duel.remove.message_ended"
            : "duel.remove.message_active"
    }

    /// Label do botão destructive de confirmação.
    private func confirmActionKey(for match: GKTurnBasedMatch) -> LocalizedStringKey {
        return match.status == .ended
            ? "duel.remove.confirm_ended"
            : "duel.remove.confirm_active"
    }

    // MARK: - Top bar (header)

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("duel.menu.back_to_menu")
                        .font(SalvageFont.label(11))
                        .tracking(2)
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Título centralizado (absolute-positioned via overlay pra não empurrar layout)
            VStack(spacing: 2) {
                Text("duel.menu.title")
                    .font(SalvageFont.titleXL(30))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .tracking(6)
                Rectangle()
                    .fill(SalvageColor.bloodAccent)
                    .frame(width: 40, height: 1.5)
                Text("duel.menu.subtitle")
                    .font(SalvageFont.label(8))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
            }

            Spacer()

            // Signed-as microcopy — bem sutil, canto direito
            if gameCenter.isAuthenticated {
                HStack(spacing: 6) {
                    Circle()
                        .fill(SalvageColor.energyOrange)
                        .frame(width: 6, height: 6)
                    Text(gameCenter.displayName)
                        .font(SalvageFont.body(10))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
            } else {
                // Reserva espaço equivalente pro layout não pular quando autentica
                Color.clear.frame(width: 80, height: 24)
            }
        }
    }

    // MARK: - Dashboard body (autenticado)

    private var dashboardBody: some View {
        VStack(spacing: 4) {
            // Row principal: rating hero (esquerda) + matches (direita)
            HStack(alignment: .top, spacing: 12) {
                ratingHeroCard
                    .frame(width: 240)
                matchesPanel
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            // Padding vertical interno — reduz altura efetiva dos containers
            // deixando bg do menu visível em cima e embaixo (sem hack de
            // .frame(height:) que quebra background dos cards internos).
            .padding(.vertical, 4)

            // Footer: 5 ações em row
            actionsFooter
        }
        // Padding horizontal maior — reduz largura efetiva dos 2 containers
        // proporcionalmente, deixando bg do menu visível nas laterais.
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
    }

    // MARK: - Rating hero (esquerda)

    private var ratingHeroCard: some View {
        let rating = ratingStore.currentRating
        let tier = RatingTier.tier(for: rating)
        let nextMin = tier.nextTierMinRating
        let showWinrate = ratingStore.totalMatches > 5

        // Progress dentro do tier (0.0 a 1.0)
        let progress: Double = {
            guard let nextMin = nextMin else { return 1.0 }  // topo
            let tierMin = tier.minRating
            let raw = Double(rating - tierMin) / Double(nextMin - tierMin)
            return max(0, min(1, raw))
        }()

        return VStack(spacing: 14) {
            Spacer(minLength: 0)

            // Progress ring com badge no centro
            ZStack {
                // Track — branco com opacity baixa (era preto invisível)
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 130, height: 130)
                // Progress — só renderiza se > 0
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            tier.accentColor.gradient,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: progress)
                }

                // Badge central
                VStack(spacing: 2) {
                    Image(tier.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                    Text("\(rating)")
                        .font(SalvageFont.number(28))
                        .foregroundStyle(SalvageColor.boneWhite)
                }
            }

            // Nome do tier
            Text(tier.displayNameKey)
                .font(SalvageFont.header(14))
                .foregroundStyle(tier.accentColor)
                .tracking(4)

            // Próximo tier hint
            if let nextMin = nextMin {
                Text("duel.rank.next_tier_at \(nextMin)")
                    .font(SalvageFont.body(10))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text("duel.rank.max_tier")
                    .font(SalvageFont.body(10))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1)
            }

            // Divisor + W/L
            if ratingStore.totalMatches > 0 {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                HStack(spacing: 6) {
                    Text("duel.rank.wins_short \(ratingStore.wins)")
                        .foregroundStyle(SalvageColor.energyOrange.opacity(0.9))
                    Text("·").foregroundStyle(.white.opacity(0.35))
                    Text("duel.rank.losses_short \(ratingStore.losses)")
                        .foregroundStyle(SalvageColor.bloodAccent.opacity(0.9))
                    if showWinrate {
                        Text("·").foregroundStyle(.white.opacity(0.35))
                        Text("duel.rank.winrate \(Int(ratingStore.winrate * 100))")
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .font(SalvageFont.number(12))
            } else {
                Text("duel.rank.no_matches_yet")
                    .font(SalvageFont.body(10))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tier.accentColor.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Matches panel (direita)

    private var matchesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("duel.menu.my_duels")
                    .font(SalvageFont.label(10))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(3)
                Spacer()
                Button {
                    matchList.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Banner discreto pra push notifications — só aparece se player
            // NÃO decidiu ainda OU negou (nesse caso oferece abrir Settings).
            // Se já autorizado, some. Não é modal invasivo.
            pushNotificationsBanner

            matchesContent
                .frame(maxHeight: .infinity)

            if let error = matchList.lastError {
                Text(error.localizedDescription)
                    .font(SalvageFont.body(10))
                    .foregroundStyle(.orange.opacity(0.7))
                    .padding(.horizontal, 4)
            }
        }
        .padding(8)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.45))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Push notifications banner (discreto, contextual)

    /// Banner que oferece habilitar push notifications. State-driven:
    ///   - `.notDetermined` → mostra "Habilitar notificações" (pede permissão)
    ///   - `.denied` → mostra "Habilitar em Ajustes" (abre Settings.app)
    ///   - `.authorized`, `.provisional`, `.ephemeral` → não mostra nada
    ///
    /// Some completamente quando autorizado — não polui a UI depois de
    /// resolvido.
    @ViewBuilder
    private var pushNotificationsBanner: some View {
        switch pushManager.authorizationStatus {
        case .notDetermined:
            pushBannerCard(
                icon: "bell.badge.fill",
                titleKey: "duel.push.enable_title",
                bodyKey: "duel.push.enable_body",
                actionKey: "duel.push.enable_action"
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                pushManager.requestAuthorization { _ in
                    // Sem callback UI-side — banner some sozinho ao autorizar
                    // (bindable reage à mudança de authorizationStatus).
                }
            }

        case .denied:
            pushBannerCard(
                icon: "bell.slash.fill",
                titleKey: "duel.push.denied_title",
                bodyKey: "duel.push.denied_body",
                actionKey: "duel.push.denied_action"
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                pushManager.openSystemSettings()
            }

        case .authorized, .provisional, .ephemeral:
            EmptyView()

        @unknown default:
            EmptyView()
        }
    }

    private func pushBannerCard(
        icon: String,
        titleKey: LocalizedStringKey,
        bodyKey: LocalizedStringKey,
        actionKey: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(SalvageColor.energyOrange)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(titleKey)
                    .font(SalvageFont.header(11))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .tracking(2)

                Text(bodyKey)
                    .font(SalvageFont.body(10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: action) {
                    Text(actionKey)
                        .font(SalvageFont.label(10))
                        .tracking(2)
                        .foregroundStyle(SalvageColor.energyOrange)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(SalvageColor.energyOrange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(SalvageColor.energyOrange.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var matchesContent: some View {
        if matchList.isLoading && matchList.matches.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                ProgressView().controlSize(.small).tint(.white.opacity(0.7))
                Text("duel.menu.loading")
                    .font(SalvageFont.body(11))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if matchList.matches.isEmpty {
            emptyMatchesView
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(matchList.matches, id: \.matchID) { match in
                        matchRow(match)
                    }
                }
            }
        }
    }

    private var emptyMatchesView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "flag.slash")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.25))
            Text("duel.menu.no_active")
                .font(SalvageFont.header(13))
                .foregroundStyle(.white.opacity(0.6))
            Text("duel.menu.tap_new_hint")
                .font(SalvageFont.body(11))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Match row (usada dentro do painel)

    private func matchRow(_ match: GKTurnBasedMatch) -> some View {
        // Tier do oponente (Fase 10) — via metadata cacheado no MatchListStore
        let opponentTier: RatingTier? = {
            guard let meta = matchList.metadata(for: match),
                  let myID = GameCenterManager.shared.myGamePlayerID,
                  let oppRating = meta.opponentRating(for: myID) else { return nil }
            return RatingTier.tier(for: oppRating)
        }()

        return Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            onOpenMatch(match)
        } label: {
            HStack(spacing: 12) {
                // Indicador de turno — pulse se é sua vez
                turnIndicator(isMyTurn: match.isMyTurn)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(opponentDisplayName(for: match))
                            .font(SalvageFont.header(13))
                            .foregroundStyle(SalvageColor.boneWhite)
                            .lineLimit(1)
                        if let tier = opponentTier {
                            tierMiniBadge(tier: tier)
                        }
                    }
                    Text(match.shortStatusLabel)
                        .font(SalvageFont.body(10))
                        .foregroundStyle(match.isMyTurn
                                         ? SalvageColor.energyOrange.opacity(0.95)
                                         : .white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                match.isMyTurn
                    ? SalvageColor.energyOrange.opacity(0.12)
                    : Color.black.opacity(0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4).stroke(
                    match.isMyTurn
                        ? SalvageColor.energyOrange.opacity(0.55)
                        : Color.white.opacity(0.1),
                    lineWidth: 1
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        // Long-press abre context menu com opção destrutiva de remover.
        // Padrão iOS descobrível — não polui a row com botão trash sempre visível.
        .contextMenu {
            Button(role: .destructive) {
                matchPendingRemoval = match
            } label: {
                Label(removeLabelKey(for: match), systemImage: "trash")
            }
        }
    }

    /// Label do menu de remoção contextual — muda conforme match está ativo
    /// (é forfeit + remove) ou já terminou (só remove da lista).
    private func removeLabelKey(for match: GKTurnBasedMatch) -> LocalizedStringKey {
        switch match.status {
        case .ended:
            return "duel.menu.remove_ended"
        case .open, .matching, .unknown:
            return "duel.menu.forfeit_and_remove"
        @unknown default:
            return "duel.menu.remove_ended"
        }
    }

    private func turnIndicator(isMyTurn: Bool) -> some View {
        ZStack {
            if isMyTurn {
                Circle()
                    .fill(SalvageColor.energyOrange.opacity(0.35))
                    .frame(width: 16, height: 16)
                    .modifier(PulseModifier())
            }
            Circle()
                .fill(isMyTurn ? SalvageColor.energyOrange : Color.white.opacity(0.25))
                .frame(width: 8, height: 8)
        }
        .frame(width: 16, height: 16)
    }

    private func tierMiniBadge(tier: RatingTier) -> some View {
        HStack(spacing: 3) {
            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
            Text(tier.displayNameKey)
                .font(SalvageFont.label(8))
                .tracking(1)
        }
        .foregroundStyle(tier.accentColor)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(tier.accentColor.opacity(0.18))
        .clipShape(Capsule())
    }

    private func opponentDisplayName(for match: GKTurnBasedMatch) -> String {
        match.opponent?.player?.displayName
            ?? String(localized: "duel.status.waiting_opponent")
    }

    // MARK: - Actions footer (linha inteira)

    private var actionsFooter: some View {
        HStack(spacing: 8) {
            actionButton(
                titleKey: "duel.menu.new_duel",
                subtitleKey: "duel.menu.new_duel_subtitle",
                icon: "plus.circle.fill",
                primary: true
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                // Abre LobbyView custom com UX de "procurando adversário".
                // Antes chamava MatchmakerPresenter.presentNewMatch() que
                // abria VC nativo do Apple com 2 tabs (Play Now/Friends) —
                // menos integrado visualmente com o app.
                onOpenLobby()
            }

            // CONVIDAR AMIGO — Fase 11.5: bypass do auto-match (que é frágil
            // em apps novos). Abre VC direto no picker de amigos do Game Center.
            // Push chega instantâneo pro amigo — funciona em 100% dos casos
            // se ambos estão online, ao contrário de auto-match.
            actionButton(
                titleKey: "duel.menu.invite_friend",
                subtitleKey: "duel.menu.invite_friend_subtitle",
                icon: "person.badge.plus.fill",
                primary: false
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                MatchmakerPresenter.shared.presentInviteFriend()
            }

            actionButton(
                titleKey: "duel.menu.my_deck",
                subtitleKey: LocalizedStringKey("duel.menu.my_deck_subtitle \(DeckStore.shared.currentDeck.totalCards) \(DuelDeckConfig.deckSize)"),
                icon: "square.stack.3d.up.fill",
                primary: false
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                onOpenDeckBuilder()
            }

            actionButton(
                titleKey: "duel.menu.leaderboard",
                subtitleKey: "duel.menu.leaderboard_subtitle",
                icon: "trophy.fill",
                iconTint: .yellow.opacity(0.8),
                primary: false
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                presentLeaderboard()
            }

            actionButton(
                titleKey: "duel.menu.history",
                subtitleKey: MatchHistoryStore.shared.entries.isEmpty
                    ? LocalizedStringKey("duel.menu.history_subtitle_empty")
                    : LocalizedStringKey("duel.menu.history_subtitle \(MatchHistoryStore.shared.entries.count)"),
                icon: "clock.arrow.circlepath",
                primary: false
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                onOpenHistory()
            }
        }
    }

    /// Botão compacto do footer. `primary=true` destaca com background laranja
    /// (o NOVO DUELO); os outros ficam sutis.
    private func actionButton(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey,
        icon: String,
        iconTint: Color? = nil,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let tint = iconTint ?? (primary ? SalvageColor.energyOrange : .white.opacity(0.7))

        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey)
                        .font(SalvageFont.header(12))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .tracking(2)
                        .lineLimit(1)
                    Text(subtitleKey)
                        .font(SalvageFont.body(9))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                primary
                    ? SalvageColor.energyOrange.opacity(0.18)
                    : Color.black.opacity(0.55)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        primary
                            ? SalvageColor.energyOrange.opacity(0.7)
                            : Color.white.opacity(0.18),
                        lineWidth: primary ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leaderboard presentation

    private func presentLeaderboard() {
        // Fase 11: abre tela DEFAULT do Game Center — user navega entre
        // Leaderboards e Achievements nas tabs internas. Melhor que dedicar
        // botões separados que quebram o layout do footer.
        let vc = GKGameCenterViewController(state: .default)
        vc.gameCenterDelegate = LeaderboardPresentDelegate.shared
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var topController = root
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(vc, animated: true)
        }
    }

    // MARK: - Unauthenticated body (fallback)

    private var unauthenticatedBody: some View {
        VStack(spacing: 20) {
            Spacer()
            unauthenticatedCard.frame(maxWidth: 520)
            troubleshootingBox.frame(maxWidth: 520)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var unauthenticatedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .font(.title2)
                Text("duel.auth.not_authenticated")
                    .font(SalvageFont.header(15))
                    .foregroundStyle(SalvageColor.boneWhite)
                Spacer()
            }

            if let error = gameCenter.lastAuthError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("duel.auth.apple_error_label")
                        .font(SalvageFont.label(9))
                        .foregroundStyle(.orange.opacity(0.7))
                        .tracking(3)
                    Text(error.localizedDescription)
                        .font(SalvageFont.body(12))
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                gameCenter.authenticate()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("duel.auth.retry")
                        .font(SalvageFont.label(10))
                        .tracking(2)
                }
                .foregroundStyle(SalvageColor.boneWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(SalvageColor.bloodAccent.opacity(0.5))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color.black.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var troubleshootingBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("duel.auth.checklist_title")
                .font(SalvageFont.label(9))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(3)
            checklistItem("duel.auth.check_signin_title", "duel.auth.check_signin_detail")
            checklistItem("duel.auth.check_capability_title", "duel.auth.check_capability_detail")
            checklistItem("duel.auth.check_asc_title", "duel.auth.check_asc_detail")
        }
        .padding(16)
        .background(Color.black.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func checklistItem(_ titleKey: LocalizedStringKey, _ detailKey: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titleKey).font(SalvageFont.header(11)).foregroundStyle(SalvageColor.boneWhite.opacity(0.85))
            Text(detailKey).font(SalvageFont.body(10)).foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - Pulse modifier (indicador "sua vez")

/// Anima escala e opacidade em loop pra criar efeito de pulse suave no dot
/// "sua vez" — chama atenção sem ser irritante.
private struct PulseModifier: ViewModifier {
    @State private var animate: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(animate ? 1.6 : 1.0)
            .opacity(animate ? 0.0 : 0.9)
            .animation(
                .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                value: animate
            )
            .onAppear { animate = true }
    }
}
