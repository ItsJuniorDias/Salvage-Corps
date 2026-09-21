//
//  RootView.swift
//  Salvage Corps
//
//  Root view — Map-first architecture.
//  Fluxo: Menu → MapView → (Combat|Camp|Event) → volta pra MapView.
//

import SwiftUI
import Pow
import SalvageCore
import GameKit

struct RootView: View {

    // Stores globais
    @State private var mapStore = MapStore()
    @State private var progressStore = ProgressStore()

    // Run em andamento
    @State private var combatStore: GameStore? = nil
    @State private var currentNode: MapNode? = nil
    @State private var currentScreen: RunScreen = .menu

    // Post-combat upgrade offer
    @State private var postCombatOfferCard: Card? = nil
    @State private var postCombatOfferPaths: [CardUpgrade] = []

    // Terminal choice (fim de ato)
    @State private var pendingTerminalAct: Int? = nil

    // Ending screen (fim do jogo — Ato 3)
    @State private var pendingEnding: EndingPath? = nil

    // Dev menu (long-press no version label)
    @State private var showDevMenu: Bool = false

    // Duelos — stores compartilhados enquanto o modo estiver ativo
    @State private var matchListStore = MatchListStore()
    @State private var duelMatchStore: DuelMatchStore? = nil

    // Anim
    @State private var titleAppeared: Bool = false
    @State private var showResetConfirm: Bool = false

    // Singleton observable — sem wrapper
    private let audio = AudioManager.shared

    var body: some View {
        ZStack {
            switch currentScreen {
            case .menu:
                menuView
                    .transition(.movingParts.blur.combined(with: .opacity))

            case .map:
                MapView(mapStore: mapStore) { node in
                    handleNodeSelection(node)
                }
                .transition(.movingParts.blur.combined(with: .opacity))
                .overlay(alignment: .topLeading) { backToMenuButton }

            case .combat:
                if let combatStore, let node = currentNode {
                    CombatView(
                        store: combatStore,
                        node: node,
                        onCompletion: { completedNode, victory in
                            handleCombatEnd(node: completedNode, victory: victory)
                        },
                        onAbandon: {
                            handleAbandonRun()
                        }
                    )
                    .transition(.movingParts.iris())
                }

            case .camp:
                if let node = currentNode {
                    CampView(node: node, mapStore: mapStore, progressStore: progressStore) {
                        returnToMap()
                    }
                    .transition(.movingParts.blur.combined(with: .opacity))
                }

            case .event:
                if let node = currentNode {
                    EventView(node: node, mapStore: mapStore) {
                        returnToMap()
                    }
                    .transition(.movingParts.blur.combined(with: .opacity))
                }

            case .postCombatOffer:
                if let card = postCombatOfferCard {
                    PostCombatUpgradeOfferView(
                        card: card,
                        paths: postCombatOfferPaths,
                        onApply: { upgrade in
                            handlePostCombatUpgrade(templateID: card.templateID ?? "", upgrade: upgrade)
                        },
                        onSkip: {
                            handlePostCombatSkip()
                        }
                    )
                    .transition(.opacity)
                }

            case .terminalChoice:
                if let act = pendingTerminalAct {
                    TerminalChoiceView(act: act) { choice in
                        handleTerminalChoice(choice)
                    }
                    .transition(.movingParts.blur.combined(with: .opacity))
                }

            case .ending:
                if let ending = pendingEnding {
                    EndingView(
                        ending: ending,
                        consequences: progressStore.consequences
                    ) {
                        handleEndingDismiss()
                    }
                    .transition(.opacity)
                }

            case .duels:
                DuelsMenuView(
                    gameCenter: GameCenterManager.shared,
                    matchList: matchListStore,
                    ratingStore: RatingStore.shared,
                    onOpenMatch: { match in
                        duelMatchStore = DuelMatchStore(match: match)
                        withAnimation { currentScreen = .duelMatch }
                    },
                    onOpenDeckBuilder: {
                        withAnimation { currentScreen = .deckBuilder }
                    },
                    onOpenHistory: {
                        withAnimation { currentScreen = .matchHistory }
                    },
                    onBack: {
                        withAnimation { currentScreen = .menu }
                    },
                    onOpenLobby: {
                        // Fase 12: LobbyView custom em vez de VC nativo Apple
                        withAnimation { currentScreen = .duelLobby }
                    }
                )

            case .duelLobby:
                LobbyView(
                    onMatchFound: { match in
                        // Auto-match retornou match completo (2 players) →
                        // abre direto na tela de combate PVP.
                        duelMatchStore = DuelMatchStore(match: match)
                        withAnimation { currentScreen = .duelMatch }
                    },
                    onCancel: {
                        // Player cancelou OU vai pro fallback (invite friend)
                        withAnimation { currentScreen = .duels }
                    }
                )
                .transition(.movingParts.blur.combined(with: .opacity))

            case .deckBuilder:
                DeckBuilderView(deckStore: DeckStore.shared) {
                    withAnimation { currentScreen = .duels }
                }
                .transition(.movingParts.blur.combined(with: .opacity))

            case .matchHistory:
                MatchHistoryView(historyStore: MatchHistoryStore.shared) {
                    withAnimation { currentScreen = .duels }
                }
                .transition(.movingParts.blur.combined(with: .opacity))

            case .duelMatch:
                if let store = duelMatchStore {
                    DuelMatchView(store: store) {
                        duelMatchStore = nil
                        withAnimation { currentScreen = .duels }
                    }
                    .transition(.movingParts.blur.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentScreen)
        .onAppear {
            // Se já tem run em andamento (save recuperado), abre direto no mapa
            if mapStore.hasActiveRun {
                currentScreen = .map
            }
            AudioManager.shared.playMusic(AudioTrack.musicMenu)
        }
        // Deep-link de push notification: quando player toca notification
        // de "é sua vez", navega direto pro match (ou menu de Duels se não
        // conseguiu extrair matchID do payload).
        .onReceive(NotificationCenter.default.publisher(for: .pnDidTapMatchNotification)) { notif in
            handlePushMatchTap(matchID: notif.object as? String)
        }
    }

    /// Trata tap em push notification. Se veio matchID, busca no matchList
    /// e abre direto no DuelMatchStore. Se não, apenas navega pro menu de
    /// Duels — player vê a lista atualizada e escolhe.
    private func handlePushMatchTap(matchID: String?) {
        // Garante que GC tá autenticado antes de tentar navegar
        guard GameCenterManager.shared.isAuthenticated else {
            print("[RootView] push tap ignored — GC not authenticated")
            return
        }

        if let matchID = matchID {
            // Refresh lista pra pegar estado fresco, depois procura match
            matchListStore.refresh()
            // Pequeno delay pra deixar o refresh voltar antes de tentar abrir
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                if let match = matchListStore.matches.first(where: { $0.matchID == matchID }) {
                    print("[RootView] opening match from push: \(matchID)")
                    duelMatchStore = DuelMatchStore(match: match)
                    withAnimation { currentScreen = .duelMatch }
                } else {
                    print("[RootView] match \(matchID) not found in list — showing Duels menu")
                    withAnimation { currentScreen = .duels }
                }
            }
        } else {
            print("[RootView] push tap without matchID — routing to Duels menu")
            withAnimation { currentScreen = .duels }
        }
    }

    // MARK: - Menu principal

    private var menuView: some View {
        ZStack {
            Image("bg_trench")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.85), Color.black.opacity(0.65), Color.black.opacity(0.85)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            HStack(alignment: .center, spacing: 32.s) {
                titleColumn.frame(maxWidth: .infinity)
                actionsColumn.frame(maxWidth: 380.s)
            }
            .padding(.horizontal, 40.s)
            .padding(.vertical, 24.s)
        }
        .overlay(alignment: .topTrailing) { audioButton.padding() }
        .preferredColorScheme(.dark)
        .alert("menu.abandon_confirm_title", isPresented: $showResetConfirm) {
            Button("common.cancel", role: .cancel) {}
            Button("common.abandon", role: .destructive) {
                mapStore.abandonRun()
            }
        } message: {
            Text("menu.abandon_confirm_message")
        }
        .confirmationDialog(
            "Dev Menu",
            isPresented: $showDevMenu,
            titleVisibility: .visible
        ) {
            Button("Desbloquear todos os atos") {
                progressStore.debugUnlockAllActs()
            }
            Button("Simular escolhas: Path Cúmplice") {
                progressStore.debugSimulateAllChoices(path: .complice)
            }
            Button("Simular escolhas: Path Contentor") {
                progressStore.debugSimulateAllChoices(path: .contentor)
            }
            Button("Simular escolhas: Path Testemunha") {
                progressStore.debugSimulateAllChoices(path: .testemunha)
            }
            Button("Simular Fugitivo (Testemunha + walkAway)") {
                progressStore.debugSimulateFugitivoPath()
            }
            Button("Simular O Espelho (secreto)") {
                progressStore.debugSimulateEspelhoPath()
            }
            Button("Resetar TUDO (progresso + escolhas)", role: .destructive) {
                progressStore.reset()
                mapStore.abandonRun()
            }
            Button("Fechar", role: .cancel) {}
        } message: {
            let ends = progressStore.consequences.allChoices.map { $0.rawValue }
            Text("""
                Progresso: Ato \(progressStore.highestActCompleted)
                Escolhas: \(ends.isEmpty ? "nenhuma" : ends.joined(separator: ", "))
                """)
        }
    }

    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 16.s) {
            Spacer()

            VStack(alignment: .leading, spacing: 8.s) {
                Text("SALVAGE")
                    .font(SalvageFont.titleXL(56))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .tracking(6.s)
                    .changeEffect(.shine.delay(0.5), value: titleAppeared)

                Text("CORPS")
                    .font(SalvageFont.titleXL(56))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .tracking(6.s)
                    .changeEffect(.shine.delay(0.7), value: titleAppeared)

                Text("ATO I · v0.2")
                    .font(SalvageFont.label(11))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(4.s)
                    .padding(.top, 4.s)
                    .onLongPressGesture(minimumDuration: 1.5) {
                        AudioManager.shared.playSFX(AudioTrack.sfxClick)
                        showDevMenu = true
                    }
            }

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s).padding(.vertical, 8.s)

            Text("menu.epigraph")
                .font(SalvageFont.flavor(15))
                .italic()
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(4.s)

            Text("menu.epigraph_attribution")
                .font(SalvageFont.label(9))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2.s)
                .padding(.top, 4.s)

            Spacer()
        }
        .onAppear { titleAppeared = true }
    }

    private var actionsColumn: some View {
        VStack(alignment: .leading, spacing: 12.s) {
            Spacer()

            Text("menu.subtitle")
                .font(SalvageFont.label(10))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(3.s)
                .padding(.bottom, 6.s)

            // "Continuar" — só aparece se tem run em andamento
            if mapStore.hasActiveRun {
                actionButton(
                    title: "menu.continue_run",
                    subtitle: "menu.continue_run_subtitle \(mapStore.currentAct)",
                    icon: "arrow.forward.circle.fill",
                    prominent: true
                ) {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    withAnimation { currentScreen = .map }
                }

                actionButton(
                    title: "menu.abandon_run",
                    subtitle: "menu.abandon_run_subtitle",
                    icon: "xmark.circle",
                    prominent: false
                ) {
                    showResetConfirm = true
                }
            } else {
                // Ato I — sempre desbloqueado
                actionButton(
                    title: "menu.new_run_act1",
                    subtitle: "menu.new_run_act1_subtitle",
                    icon: "play.circle.fill",
                    prominent: true
                ) {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    mapStore.startNewRun(act: 1)
                    withAnimation { currentScreen = .map }
                }

                // Ato II — trancado até vencer boss Ato I
                let act2Unlocked = progressStore.isActUnlocked(2)
                actionButton(
                    title: "menu.new_run_act2",
                    subtitle: act2Unlocked
                        ? "menu.new_run_act2_subtitle_unlocked"
                        : "menu.new_run_act2_subtitle_locked",
                    icon: act2Unlocked ? "arrow.down.circle.fill" : "lock.fill",
                    prominent: true,
                    disabled: !act2Unlocked
                ) {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    mapStore.startNewRun(act: 2)
                    withAnimation { currentScreen = .map }
                }

                // Ato III — trancado até vencer boss Ato II
                let act3Unlocked = progressStore.isActUnlocked(3)
                actionButton(
                    title: "menu.new_run_act3",
                    subtitle: act3Unlocked
                        ? "menu.new_run_act3_subtitle_unlocked"
                        : "menu.new_run_act3_subtitle_locked",
                    icon: act3Unlocked ? "eye.circle.fill" : "lock.fill",
                    prominent: true,
                    disabled: !act3Unlocked
                ) {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    mapStore.startNewRun(act: 3)
                    withAnimation { currentScreen = .map }
                }

                // Preview do ending path se já tem escolhas
                if let prediction = progressStore.consequences.currentEndingPrediction {
                    HStack(spacing: 6.s) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9.s))
                        Text("menu.current_path \(prediction.localizedName)")
                            .font(SalvageFont.label(9))
                            .tracking(2.s)
                    }
                    .foregroundStyle(SalvageColor.scarGold.opacity(0.8))
                    .padding(.top, 8.s)
                }
            }

            // Botão Duelos — SEMPRE clicável. A DuelsMenuView mostra o estado
            // real do auth (autenticado, aguardando, ou erro). Se ficasse
            // desabilitado, um erro de auth ficava invisível — pior UX.
            #if !ITCH
            duelsButton()
                .padding(.top, 8.s)
            #endif

            Spacer()
        }
    }

    /// Botão que abre o modo Duelos PvP. Layout compacto pra não competir
    /// visualmente com os CTAs de campanha. Sempre habilitado — a DuelsMenuView
    /// mostra o estado de auth.
    private func duelsButton() -> some View {
        let authed = GameCenterManager.shared.isAuthenticated
        return Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            withAnimation { currentScreen = .duels }
        } label: {
            HStack(spacing: 10.s) {
                Image(systemName: "person.2.crop.square.stack.fill")
                    .font(.system(size: 20.s))
                    .foregroundStyle(SalvageColor.bloodAccent)
                    .frame(width: 24.s)

                VStack(alignment: .leading, spacing: 2.s) {
                    Text("menu.duels.title")
                        .font(SalvageFont.header(13))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .tracking(2.s)

                    Text(authed
                         ? LocalizedStringKey("menu.duels.subtitle")
                         : LocalizedStringKey("menu.duels.subtitle_auth_error"))
                        .font(SalvageFont.body(10))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Indicador visual do status sem impedir click
                if !authed {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12.s))
                        .foregroundStyle(Color.orange.opacity(0.8))
                }
            }
            .padding(.horizontal, 14.s)
            .padding(.vertical, 10.s)
            .background(Color.black.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 4.s)
                    .stroke(SalvageColor.bloodAccent.opacity(0.4), lineWidth: 1.s)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4.s))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        prominent: Bool,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20.s))
                    .foregroundStyle(
                        disabled ? .white.opacity(0.3)
                        : (prominent ? SalvageColor.energyOrange : .white.opacity(0.5))
                    )
                    .frame(width: 24.s)

                VStack(alignment: .leading, spacing: 2.s) {
                    Text(title)
                        .font(SalvageFont.header(15))
                        .foregroundStyle(
                            disabled ? SalvageColor.boneWhite.opacity(0.4) : SalvageColor.boneWhite
                        )
                    Text(subtitle)
                        .font(SalvageFont.body(10))
                        .foregroundStyle(
                            disabled ? .white.opacity(0.35) : .white.opacity(0.65)
                        )
                }

                Spacer()

                // Cadeado no canto direito quando disabled
                if disabled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12.s))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 14.s)
            .padding(.vertical, 10.s)
            .background(Color.black.opacity(disabled ? 0.35 : (prominent ? 0.65 : 0.4)))
            .overlay(
                RoundedRectangle(cornerRadius: 4.s)
                    .stroke(
                        disabled ? Color.white.opacity(0.12)
                        : (prominent ? SalvageColor.energyOrange.opacity(0.6) : Color.white.opacity(0.2)),
                        lineWidth: disabled ? 1 : (prominent ? 1.5 : 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4.s))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Overlays

    private var audioButton: some View {
        Button {
            audio.isMuted.toggle()
        } label: {
            Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20.s))
                .foregroundStyle(.white.opacity(0.7))
                .padding(8.s)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
    }

    private var backToMenuButton: some View {
        Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            withAnimation {
                currentScreen = .menu
                AudioManager.shared.playMusic(AudioTrack.musicMenu)
            }
        } label: {
            Image(systemName: "chevron.left.circle.fill")
                .font(.system(size: 22.s))
                .foregroundStyle(.white, .black.opacity(0.7))
        }
        .padding()
    }

    // MARK: - Node dispatch

    private func handleNodeSelection(_ node: MapNode) {
        // Move o player pro nó no MapStore
        guard mapStore.moveToNode(node.id) else { return }
        AudioManager.shared.playSFX(AudioTrack.sfxClick)

        currentNode = node

        switch node.kind {
        case .combat, .elite, .boss:
            // Deriva encounter do ato atual e inicia combate com HP/Moral
            // acumulados da run + deck com upgrades aplicados.
            // Corrupção ativa do Ato 2 em diante.
            let enemies = node.makeEncounter(act: mapStore.currentAct)
            combatStore = GameStore.newCombat(
                enemies: enemies,
                currentHP: mapStore.runPlayerState.hp,
                maxHP: mapStore.runPlayerState.maxHP,
                currentMoral: mapStore.runPlayerState.moral,
                maxMoral: mapStore.runPlayerState.maxMoral,
                playerDeck: mapStore.playerDeck,
                corruptionEnabled: mapStore.currentAct >= 2
            )
            withAnimation {
                currentScreen = .combat
                AudioManager.shared.playMusic(AudioTrack.musicCombat)
            }

        case .camp:
            withAnimation { currentScreen = .camp }

        case .event:
            withAnimation { currentScreen = .event }

        case .merchant:
            // Não implementado ainda — trata como camp por enquanto
            withAnimation { currentScreen = .camp }
        }
    }

    private func handleCombatEnd(node: MapNode, victory: Bool) {
        // Sempre captura HP/Moral finais pro runPlayerState (mesmo em derrota, pra estatística)
        if let store = combatStore {
            mapStore.updateRunPlayerStateAfterCombat(
                hp: store.state.player.hp,
                moral: store.state.player.moral
            )
        }

        if victory {
            mapStore.markCurrentNodeResolved()

            // Se venceu boss, dispara escolha terminal ANTES de fechar o ato
            if node.kind == .boss {
                let currentAct = mapStore.currentAct
                combatStore = nil
                currentNode = nil
                pendingTerminalAct = currentAct
                withAnimation {
                    currentScreen = .terminalChoice
                    AudioManager.shared.playMusic(AudioTrack.musicMenu)  // atmosfera pós-combate
                }
                return
            }

            // Combate normal ou elite vencido — 30% chance de oferecer upgrade
            // (elite = 50% pra recompensar o desafio)
            let chance = node.kind == .elite ? 50 : 30
            if shouldOfferPostCombatUpgrade(chance: chance) {
                if let (upgradeCard, paths) = pickPostCombatUpgradeCandidate() {
                    combatStore = nil
                    currentNode = nil
                    postCombatOfferCard = upgradeCard
                    postCombatOfferPaths = paths
                    withAnimation { currentScreen = .postCombatOffer }
                    return
                }
            }
        } else {
            // Derrota — perde a run
            mapStore.abandonRun()
            withAnimation {
                currentScreen = .menu
                AudioManager.shared.playMusic(AudioTrack.musicMenu)
            }
            return
        }

        // Retorna pro mapa (vitória em nó não-boss)
        combatStore = nil
        currentNode = nil
        withAnimation { currentScreen = .map }
    }

    // MARK: - Post-combat upgrade

    /// Rola dado determinístico baseado no estado atual do progresso da run.
    /// Seed muda a cada combate resolvido pra não dar mesma sequência.
    private func shouldOfferPostCombatUpgrade(chance: Int) -> Bool {
        let seed = UInt64(bitPattern: Int64(mapStore.resolvedNodeIDs.count &* 31))
        var rng = SeededRandom(seed: seed == 0 ? 1 : seed)
        return rng.int(in: 1...100) <= chance
    }

    /// Pega uma carta disponível pra oferecer upgrade. Nil se todas já têm cicatriz.
    private func pickPostCombatUpgradeCandidate() -> (card: Card, paths: [CardUpgrade])? {
        let templates = StarterDeck.uniqueTemplates(with: mapStore.playerDeck)
        let available = templates.filter { card in
            guard let tid = card.templateID else { return false }
            return !mapStore.playerDeck.hasUpgrade(templateID: tid)
        }
        guard !available.isEmpty else { return nil }

        // Determinístico pelo mesmo seed do roll
        let seed = UInt64(bitPattern: Int64(mapStore.resolvedNodeIDs.count &* 47 &+ 13))
        var rng = SeededRandom(seed: seed == 0 ? 1 : seed)
        let index = rng.int(in: 0...(available.count - 1))
        let card = available[index]

        let paths = UpgradeCatalog.upgrades(for: card.templateID ?? "")
        guard !paths.isEmpty else { return nil }
        return (card, paths)
    }

    private func handlePostCombatUpgrade(templateID: String, upgrade: CardUpgrade) {
        mapStore.applyCardUpgrade(templateID: templateID, upgradeID: upgrade.id)
        AudioManager.shared.playSFX(AudioTrack.sfxVictory)
        postCombatOfferCard = nil
        postCombatOfferPaths = []
        withAnimation { currentScreen = .map }
    }

    private func handlePostCombatSkip() {
        AudioManager.shared.playSFX(AudioTrack.sfxClick)
        postCombatOfferCard = nil
        postCombatOfferPaths = []
        withAnimation { currentScreen = .map }
    }

    // MARK: - Terminal choice (fim de ato)

    private func handleTerminalChoice(_ choice: TerminalChoice) {
        // Persiste escolha + marca ato completo
        progressStore.recordTerminalChoice(choice)
        progressStore.markActCompleted(choice.act)

        // Se era Ato 3, registra ghost cards que estavam no deck ANTES de abandonar
        if choice.act == 3 {
            progressStore.recordFinalGhostCardCount(mapStore.ghostCardsInDeck)
        }

        mapStore.abandonRun()

        pendingTerminalAct = nil
        combatStore = nil
        currentNode = nil

        // Se era o Ato 3, calcula o ending final e mostra EndingView
        if choice.act == 3 {
            if let ending = EndingCalculator.calculate(
                from: progressStore.consequences,
                meta: progressStore.metaState
            ) {
                pendingEnding = ending
                withAnimation {
                    currentScreen = .ending
                    AudioManager.shared.playMusic(AudioTrack.musicMenu)
                }
                return
            }
        }

        // Atos 1/2 — volta pro menu normalmente
        withAnimation {
            currentScreen = .menu
            AudioManager.shared.playMusic(AudioTrack.musicMenu)
        }
    }

    private func handleEndingDismiss() {
        pendingEnding = nil
        withAnimation {
            currentScreen = .menu
            AudioManager.shared.playMusic(AudioTrack.musicMenu)
        }
    }

    private func returnToMap() {
        mapStore.markCurrentNodeResolved()
        currentNode = nil
        withAnimation { currentScreen = .map }
    }

    /// Chamado quando o player abandona um combate em andamento.
    /// Convention: abandona a run inteira e volta pro menu.
    private func handleAbandonRun() {
        mapStore.abandonRun()
        combatStore = nil
        currentNode = nil
        withAnimation {
            currentScreen = .menu
            AudioManager.shared.playMusic(AudioTrack.musicMenu)
        }
    }
}

// MARK: - Screen enum

private enum RunScreen {
    case menu
    case map
    case combat
    case camp
    case event
    case postCombatOffer
    case terminalChoice
    case ending
    /// Modo Duelos PvP async via Game Center — hub de matches.
    case duels
    /// Lobby de matchmaking custom (Fase 12) — substitui VC nativo do
    /// Apple por UX própria de "procurando adversário".
    case duelLobby
    /// Deck builder (Fase 8) — pra escolher decks customizados.
    case deckBuilder
    /// Histórico de matches ranked (Fase 10).
    case matchHistory
    /// Match específico aberto (Fase 3+).
    case duelMatch
}

// MARK: - Localization helpers

/// Extension pra localizar EndingPath.rawValue via chaves `path.*` no
/// Localizable.xcstrings. Duplicada aqui do Localizations.swift pra garantir
/// que compila mesmo se o arquivo standalone não for indexado pelo Xcode.
extension EndingPath {
    var localizedName: String {
        NSLocalizedString("path.\(rawValue)", bundle: .main, comment: "Ending path display name")
    }
}

/// Extension pra localizar nomes/flavors de Card via chaves `card.<templateID>.*`
/// no Localizable.xcstrings. Se a chave não existir, retorna o valor
/// hardcoded do core como fallback (pt-BR).
extension Card {
    var localizedName: String {
        guard let tid = templateID else { return name }
        let key = "card.\(tid).name"
        let localized = NSLocalizedString(key, bundle: .main, comment: "Card name")
        // NSLocalizedString retorna a própria chave se não achou tradução
        return localized == key ? name : localized
    }

    var localizedFlavor: String {
        guard let tid = templateID else { return flavor }
        let key = "card.\(tid).flavor"
        let localized = NSLocalizedString(key, bundle: .main, comment: "Card flavor")
        return localized == key ? flavor : localized
    }
}

/// Extension pra localizar nomes/flavors de Enemy. Deriva a chave i18n do
/// `artFilename` — ex: "enemy_gas_wraith" → "enemy.gas_wraith.name" /
/// "boss_barbed_apostle" → "enemy.barbed_apostle.name". Fallback: nome do core.
extension Enemy {
    private var i18nStub: String? {
        guard let file = artFilename else { return nil }
        if file.hasPrefix("enemy_") { return String(file.dropFirst(6)) }
        if file.hasPrefix("boss_")  { return String(file.dropFirst(5)) }
        return nil
    }

    var localizedName: String {
        guard let stub = i18nStub else { return name }
        let key = "enemy.\(stub).name"
        let localized = NSLocalizedString(key, bundle: .main, comment: "Enemy name")
        return localized == key ? name : localized
    }

    var localizedFlavor: String {
        guard let stub = i18nStub else { return flavor }
        let key = "enemy.\(stub).flavor"
        let localized = NSLocalizedString(key, bundle: .main, comment: "Enemy flavor")
        return localized == key ? flavor : localized
    }
}

#Preview {
    RootView()
}
