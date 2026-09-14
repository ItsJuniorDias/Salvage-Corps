//
//  CombatView.swift
//  Salvage Corps
//
//  Tela de combate — landscape 2-zonas.
//  Top: enemies (esquerda) + player stats + END TURN (direita)
//  Bottom: hand cards + info bar
//

import SwiftUI
import Pow
import SalvageCore

struct CombatView: View {

    @Bindable var store: GameStore

    /// O nó do mapa em execução (se houver).
    let node: MapNode?

    /// Callback chamado ao terminar o combate. bool = true se vitória.
    var onCompletion: ((MapNode, Bool) -> Void)? = nil

    /// Callback chamado quando o player abandona o combate (via botão voltar).
    /// Convention: chama isso pra abandonar a run inteira e voltar pro menu.
    var onAbandon: (() -> Void)? = nil

    // MARK: - Animation state

    @State private var showAbandonConfirm: Bool = false
    @State private var selectedCardIndex: Int? = nil

    @State private var lastPlayerHPDelta: Int = 0
    @State private var lastMoralDelta: Int = 0
    @State private var lastBlockGain: Int = 0
    @State private var lastDamageByEnemy: [UUID: Int] = [:]

    @State private var shakeTriggerByCard: [UUID: Int] = [:]
    @State private var screenShakeOffset: CGFloat = 0

    @State private var showDamageFlash: Bool = false
    @State private var showMoralFlash: Bool = false
    @State private var turnBannerText: String? = nil

    // Boss phase transitions
    @State private var bossPhaseBannerText: String? = nil
    @State private var bossPhaseBannerIntro: String? = nil
    @State private var lastBossPhase: Int = 0

    @State private var cardPlayHaptic: Int = 0
    @State private var damageHaptic: Int = 0

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 8) {
                // TOP ZONE: enemies (left) + player stats + end turn (right)
                topZone

                Spacer(minLength: 0)

                // BOTTOM ZONE: hand cards + info
                handSection

                infoBar
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 6)
            .offset(x: screenShakeOffset)
        }
        .overlay { damageFlashOverlay }
        .overlay { moralFlashOverlay }
        .overlay { turnBannerOverlay }
        .overlay(alignment: .topLeading) { backButton }
        .overlay { bossPhaseBannerOverlay }
        .overlay {
            if store.state.isCombatOver {
                combatEndOverlay
                    .transition(.movingParts.blur.combined(with: .opacity))
            }
        }
        .alert("combat.abandon_confirm_title", isPresented: $showAbandonConfirm) {
            Button("common.cancel", role: .cancel) {}
            Button("common.abandon", role: .destructive) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                onAbandon?()
            }
        } message: {
            Text("combat.abandon_confirm_message")
        }
        .changeEffect(.feedback(hapticImpact: .light), value: cardPlayHaptic)
        .changeEffect(.feedback(hapticImpact: .heavy), value: damageHaptic)
        .onChange(of: store.state.player.hp) { old, new in
            handlePlayerHPChange(old: old, new: new)
        }
        .onChange(of: store.state.player.moral) { old, new in
            handleMoralChange(old: old, new: new)
        }
        .onChange(of: store.state.player.block) { old, new in
            if new > old { lastBlockGain = new - old }
        }
        .onChange(of: store.state.turn) { _, newTurn in
            if newTurn > 1 {
                showTurnBanner(String(localized: "combat.turn_banner \(newTurn)"))
            }
            AudioManager.shared.playSFX(AudioTrack.sfxTurnEnd)
        }
        .onChange(of: store.state.enemies) { oldEnemies, newEnemies in
            handleEnemiesChange(old: oldEnemies, new: newEnemies)
            checkBossPhaseTransitions(old: oldEnemies, new: newEnemies)
        }
        .onChange(of: store.state.phase) { oldPhase, newPhase in
            handlePhaseChange(old: oldPhase, new: newPhase)
        }
        .onAppear { showTurnBanner(String(localized: "combat.op_started")) }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        Image("bg_trench")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.55))
    }

    // MARK: - Top zone (enemies + stats + END TURN)

    private var topZone: some View {
        HStack(alignment: .top, spacing: 20) {
            enemiesSection
                .frame(maxWidth: .infinity, alignment: .leading)

            playerPanel
                .frame(width: 360)
        }
    }

    // MARK: - Back button (top-leading)

    /// Botão de voltar/abandonar combate. Estilo circular discreto,
    /// mesma linguagem visual do botão do MapView.
    private var backButton: some View {
        Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            showAbandonConfirm = true
        } label: {
            Image(systemName: "chevron.left.circle.fill")
                .font(.title2)
                .foregroundStyle(.white, .black.opacity(0.7))
        }
        .padding()
    }

    // MARK: - Enemies

    private var enemiesSection: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(store.state.enemies) { enemy in
                if enemy.isAlive {
                    enemyView(enemy)
                        .transition(.movingParts.vanish(.red.opacity(0.7)))
                }
            }
        }
        .animation(.spring(response: 0.5), value: store.state.enemies.map(\.isAlive))
    }

    private func enemyView(_ enemy: Enemy) -> some View {
        let isTargetable = selectedCardIndex.map { idx in
            let card = store.state.hand[idx]
            return card.targeting == .singleEnemy && enemy.isAlive
        } ?? false

        return VStack(spacing: 2) {
            ZStack {
                if let art = enemy.artFilename {
                    Image(art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 76, height: 108)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 76, height: 108)
                }

                VStack {
                    HStack {
                        Spacer()
                        if enemy.isIntentHidden {
                            // Fog of War: intent oculta — mostra ? em roxo
                            Text("?")
                                .font(SalvageFont.number(11))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(SalvageColor.moralPurple.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                        } else {
                            Text(intentText(for: enemy.currentIntent))
                                .font(SalvageFont.label(8))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(SalvageColor.energyOrange.opacity(0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .changeEffect(
                                    .jump(height: 6),
                                    value: intentHash(enemy.currentIntent)
                                )
                        }
                    }
                    Spacer()
                }
                .padding(3)
            }
            .frame(width: 76, height: 108)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isTargetable ? Color.green : Color.black.opacity(0.6),
                            lineWidth: isTargetable ? 2.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .changeEffect(.shake(rate: .fast), value: enemy.hp)

            Text(enemy.localizedName)
                .font(SalvageFont.header(9))
                .foregroundStyle(SalvageColor.boneWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 78)

            Text("\(enemy.hp)/\(enemy.maxHP)")
                .font(SalvageFont.number(9))
                .foregroundStyle(SalvageColor.hpRed)
                .changeEffect(
                    .rise(origin: .center) {
                        Text("-\(lastDamageByEnemy[enemy.id] ?? 0)")
                            .font(SalvageFont.number(20))
                            .foregroundStyle(SalvageColor.hpRed.gradient)
                            .shadow(color: .black.opacity(0.8), radius: 2)
                    },
                    value: enemy.hp
                )

            if !enemy.statusEffects.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(enemy.statusEffects.keys), id: \.self) { status in
                        Text("\(statusIcon(status))\(enemy.statusEffects[status] ?? 0)")
                            .font(SalvageFont.label(7))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(statusColor(status))
                            .clipShape(Capsule())
                            .transition(.movingParts.pop(statusColor(status)))
                    }
                }
            }
        }
        .frame(width: 82)
        .onTapGesture {
            if isTargetable, let cardIdx = selectedCardIndex {
                cardPlayHaptic += 1
                store.dispatch(.playCard(handIndex: cardIdx, targetEnemyID: enemy.id))
                selectedCardIndex = nil
            }
        }
    }

    // MARK: - Player panel (stats + END TURN button)

    private var playerPanel: some View {
        VStack(spacing: 6) {
            // Row 1: retrato + barras
            HStack(spacing: 8) {
                Image("edmund")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(SalvageColor.boneWhite.opacity(0.4), lineWidth: 1)
                    )
                    .changeEffect(.shake(rate: .fast), value: store.state.player.hp)

                VStack(alignment: .leading, spacing: 3) {
                    statBar(
                        label: "HP",
                        value: store.state.player.hp,
                        max: store.state.player.maxHP,
                        color: SalvageColor.hpRed,
                        floatingText: lastPlayerHPDelta < 0 ? "\(lastPlayerHPDelta)" : "+\(lastPlayerHPDelta)",
                        floatingColor: lastPlayerHPDelta < 0 ? .red : .green
                    )
                    statBar(
                        label: "MORAL",
                        value: store.state.player.moral,
                        max: store.state.player.maxMoral,
                        color: SalvageColor.moralPurple,
                        floatingText: lastMoralDelta < 0 ? "\(lastMoralDelta)" : "+\(lastMoralDelta)",
                        floatingColor: lastMoralDelta < 0 ? .purple : .cyan
                    )
                }
            }

            // Row 2: recursos + END TURN
            HStack(spacing: 10) {
                Label("\(store.state.player.block)", systemImage: "shield.fill")
                    .font(SalvageFont.number(11))
                    .foregroundStyle(SalvageColor.blockBlue)
                    .changeEffect(
                        .ping(shape: Circle(), style: SalvageColor.blockBlue, count: 2),
                        value: lastBlockGain
                    )

                Label(
                    "\(store.state.player.energy)/\(store.state.player.maxEnergy)",
                    systemImage: "bolt.fill"
                )
                .font(SalvageFont.number(11))
                .foregroundStyle(SalvageColor.energyOrange)
                .changeEffect(
                    .ping(shape: Capsule(), style: SalvageColor.energyOrange, count: 1),
                    value: store.state.player.energy
                )

                // Corrupção (Ato 2+): mostra stacks se > 0
                if let corruption = store.state.player.statusEffects[.corruption], corruption > 0 {
                    Label("\(corruption)", systemImage: "circle.hexagongrid.fill")
                        .font(SalvageFont.number(11))
                        .foregroundStyle(SalvageColor.gasGreen)
                        .changeEffect(
                            .ping(shape: Circle(), style: SalvageColor.gasGreen, count: 2),
                            value: corruption
                        )
                        .help(String(localized: "combat.corruption_help \(corruption)"))
                }

                Text("combat.turn_short \(store.state.turn)")
                    .font(SalvageFont.label(10))
                    .foregroundStyle(.white.opacity(0.65))
                    .tracking(1)

                Spacer()

                // BOTÃO PRINCIPAL — bem visível
                Button {
                    selectedCardIndex = nil
                    cardPlayHaptic += 1
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    store.dispatch(.endTurn)
                } label: {
                    HStack(spacing: 4) {
                        Text("combat.end_turn")
                            .font(SalvageFont.label(10))
                            .tracking(1.5)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(SalvageColor.energyOrange)
                .disabled(store.state.isCombatOver)
                .changeEffect(
                    .spray(origin: .center) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(SalvageColor.energyOrange)
                    },
                    value: store.state.turn
                )
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func statBar(
        label: String,
        value: Int,
        max: Int,
        color: Color,
        floatingText: String,
        floatingColor: Color
    ) -> some View {
        HStack(spacing: 5) {
            Text("\(label):")
                .font(SalvageFont.bodyBold(9))
                .foregroundStyle(SalvageColor.boneWhite)
                .frame(width: 42, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                    Rectangle()
                        .fill(color)
                        .frame(width: max > 0 ? geo.size.width * CGFloat(value) / CGFloat(max) : 0)
                        .animation(.spring(response: 0.4), value: value)
                }
            }
            .frame(height: 9)
            .cornerRadius(2)
            Text("\(value)/\(max)")
                .font(SalvageFont.number(9))
                .foregroundStyle(SalvageColor.boneWhite)
                .frame(width: 44, alignment: .trailing)
                .changeEffect(
                    .rise(origin: .top) {
                        Text(floatingText)
                            .font(SalvageFont.number(18))
                            .foregroundStyle(floatingColor.gradient)
                            .shadow(color: .black.opacity(0.8), radius: 2)
                    },
                    value: value
                )
        }
    }

    // MARK: - Hand

    private var handSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(store.state.hand.enumerated()), id: \.element.id) { index, card in
                    cardView(card: card, index: index)
                        .transition(.asymmetric(
                            insertion: .movingParts.pop(.orange)
                                .combined(with: .move(edge: .bottom)),
                            removal: .movingParts.poof
                        ))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 12)  // folga pro scaleEffect(1.06) + shadow radius 10
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: store.state.hand.map(\.id))
        }
        .frame(height: 184)  // 152 base + 12 top + 12 bottom + folga pra scale/shadow
    }

    private func cardView(card: Card, index: Int) -> some View {
        let canAfford = store.state.player.energy >= card.cost
        let isSelected = selectedCardIndex == index

        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("\(card.cost)")
                    .font(SalvageFont.number(12))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(canAfford ? SalvageColor.energyOrange : Color.gray))
                Text(card.localizedName)
                    .font(SalvageFont.header(10))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(5)
            .background(Color.black.opacity(0.85))

            if let art = card.artFilename {
                Image(art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 112, height: 80)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 112, height: 80)
            }

            VStack(alignment: .leading, spacing: 1) {
                ForEach(card.effects.indices, id: \.self) { i in
                    Text(effectText(card.effects[i]))
                        .font(SalvageFont.body(9))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(5)
            .background(Color(white: 0.13))
        }
        .frame(width: 112, height: 152)
        .overlay(alignment: .topTrailing) {
            // Indicador visual de cicatriz
            if !card.scars.isEmpty {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SalvageColor.scarGold)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
                    .offset(x: 6, y: -6)
                    .shadow(color: SalvageColor.scarGold.opacity(0.6), radius: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    borderColor(isSelected: isSelected, hasScars: !card.scars.isEmpty),
                    lineWidth: borderWidth(isSelected: isSelected, hasScars: !card.scars.isEmpty)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(canAfford ? 1.0 : 0.45)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .shadow(
            color: isSelected ? SalvageColor.blockBlue.opacity(0.7)
                : (!card.scars.isEmpty ? SalvageColor.scarGold.opacity(0.35) : .clear),
            radius: isSelected ? 10 : (!card.scars.isEmpty ? 5 : 0)
        )
        .changeEffect(.shine, value: isSelected)
        .changeEffect(
            .shake(rate: .fast),
            value: shakeTriggerByCard[card.id] ?? 0
        )
        .onTapGesture {
            guard canAfford else {
                shakeTriggerByCard[card.id, default: 0] += 1
                cardPlayHaptic += 1
                return
            }
            AudioManager.shared.playSFX(AudioTrack.sfxCardPlay)
            switch card.targeting {
            case .none:
                cardPlayHaptic += 1
                store.dispatch(.playCard(handIndex: index))
                selectedCardIndex = nil
            case .singleEnemy:
                selectedCardIndex = (selectedCardIndex == index) ? nil : index
            case .cardInHand:
                let others = store.state.hand.indices.filter { $0 != index }
                if let target = others.first {
                    cardPlayHaptic += 1
                    store.dispatch(.playCard(handIndex: index, targetHandIndex: target))
                }
                selectedCardIndex = nil
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Card border helpers

    private func borderColor(isSelected: Bool, hasScars: Bool) -> Color {
        if isSelected { return SalvageColor.blockBlue }
        if hasScars { return SalvageColor.scarGold.opacity(0.7) }
        return SalvageColor.boneWhite.opacity(0.3)
    }

    private func borderWidth(isSelected: Bool, hasScars: Bool) -> CGFloat {
        if isSelected { return 2.5 }
        if hasScars { return 1.5 }
        return 1
    }

    // MARK: - Info bar (deck/discard/exhaust counts)

    private var infoBar: some View {
        HStack {
            Text("combat.deck_count \(store.state.drawPile.count)")
                .font(SalvageFont.caption(9))
                .foregroundStyle(.white.opacity(0.55))
            Text(verbatim: "·")
                .foregroundStyle(.white.opacity(0.3))
            Text("combat.discard_count \(store.state.discardPile.count)")
                .font(SalvageFont.caption(9))
                .foregroundStyle(.white.opacity(0.55))
            Text(verbatim: "·")
                .foregroundStyle(.white.opacity(0.3))
            Text("combat.exile_count \(store.state.exhaustPile.count)")
                .font(SalvageFont.caption(9))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
        .tracking(1)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var damageFlashOverlay: some View {
        if showDamageFlash {
            Color.red.opacity(0.35)
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeOut(duration: 0.4)))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var moralFlashOverlay: some View {
        if showMoralFlash {
            Color.purple.opacity(0.3)
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeOut(duration: 0.4)))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var turnBannerOverlay: some View {
        if let text = turnBannerText {
            VStack {
                Spacer()
                Text(text)
                    .font(SalvageFont.titleXL(28))
                    .tracking(6)
                    .foregroundStyle(SalvageColor.boneWhite)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 10)
                    .changeEffect(.shine, value: text)
                Spacer()
            }
            .transition(.movingParts.anvil.combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }

    // MARK: - Combat end

    private var combatEndOverlay: some View {
        VStack(spacing: 14) {
            Text(endTitle)
                .font(SalvageFont.titleXL(42))
                .tracking(6)
                .foregroundStyle(SalvageColor.boneWhite)
                .changeEffect(
                    .shine.delay(0.3),
                    value: store.state.phase == .victory
                )

            Rectangle()
                .fill(SalvageColor.bloodAccent)
                .frame(width: 60, height: 2)

            Text(endSubtitle)
                .font(SalvageFont.flavor(15))
                .italic()
                .foregroundStyle(SalvageColor.boneWhite.opacity(0.8))
                .multilineTextAlignment(.center)

            Text("combat.turns_count \(store.state.turn)")
                .font(SalvageFont.label(10))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(3)
                .padding(.top, 6)
        }
        .padding(36)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }

    private var endTitle: String {
        switch store.state.phase {
        case .victory: return "VITÓRIA"
        case .defeat(let reason):
            return reason == .hp ? "MORTO" : "SUA UNIDADE QUEBROU"
        default: return ""
        }
    }

    private var endSubtitle: String {
        switch store.state.phase {
        case .victory: return "A operação foi contida. Por ora."
        case .defeat(.hp): return "Edmund não voltou desta operação."
        case .defeat(.moral): return "Os homens desertaram.\nAlguns nunca serão encontrados."
        default: return ""
        }
    }

    // MARK: - Handlers

    private func handlePlayerHPChange(old: Int, new: Int) {
        let delta = new - old
        lastPlayerHPDelta = delta
        if delta < 0 {
            triggerScreenShake(intensity: abs(delta))
            withAnimation { showDamageFlash = true }
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation { showDamageFlash = false }
            }
            if abs(delta) >= 5 { damageHaptic += 1 }
            AudioManager.shared.playSFX(AudioTrack.sfxDamagePlayer)
        }
    }

    private func handleMoralChange(old: Int, new: Int) {
        let delta = new - old
        lastMoralDelta = delta
        if delta < 0 {
            withAnimation { showMoralFlash = true }
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation { showMoralFlash = false }
            }
            AudioManager.shared.playSFX(AudioTrack.sfxMoralHit)
        }
    }

    private func handleEnemiesChange(old: [Enemy], new: [Enemy]) {
        for oldEnemy in old {
            if let newEnemy = new.first(where: { $0.id == oldEnemy.id }) {
                // Detectar dano
                if newEnemy.hp < oldEnemy.hp {
                    lastDamageByEnemy[oldEnemy.id] = oldEnemy.hp - newEnemy.hp
                    AudioManager.shared.playSFX(AudioTrack.sfxDamageEnemy)
                }
                // Detectar morte (era vivo, agora não)
                if oldEnemy.isAlive && !newEnemy.isAlive {
                    AudioManager.shared.playSFX(AudioTrack.sfxEnemyDeath)
                }
            }
        }
    }

    private func handlePhaseChange(old: CombatPhase, new: CombatPhase) {
        // Detecta vitória ou derrota — toca SFX + notifica caller
        switch new {
        case .victory:
            AudioManager.shared.playSFX(AudioTrack.sfxVictory)
            if let node {
                onCompletion?(node, true)
            }
        case .defeat:
            AudioManager.shared.playSFX(AudioTrack.sfxDefeat)
            if let node {
                onCompletion?(node, false)
            }
        default:
            break
        }
    }

    private func triggerScreenShake(intensity: Int) {
        let amount = min(CGFloat(intensity) * 0.7, 20)
        withAnimation(.default.repeatCount(5, autoreverses: true).speed(8)) {
            screenShakeOffset = -amount
        }
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.spring(response: 0.3)) {
                screenShakeOffset = 0
            }
        }
    }

    private func showTurnBanner(_ text: String) {
        withAnimation(.spring(response: 0.5)) { turnBannerText = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.4)) { turnBannerText = nil }
        }
    }

    // MARK: - Boss phase transitions

    /// Detecta mudança de fase em qualquer boss no combate.
    /// Chamado no onChange de state.enemies.
    private func checkBossPhaseTransitions(old: [Enemy], new: [Enemy]) {
        for newEnemy in new where newEnemy.isBoss {
            guard let oldEnemy = old.first(where: { $0.id == newEnemy.id }) else { continue }
            if newEnemy.currentPhaseIndex > oldEnemy.currentPhaseIndex {
                let phaseIntros = newEnemy.phaseIntros ?? []
                let intro: String? = phaseIntros.indices.contains(newEnemy.currentPhaseIndex)
                    ? phaseIntros[newEnemy.currentPhaseIndex]
                    : nil
                showBossPhaseBanner(
                    title: bossPhaseTitle(phase: newEnemy.currentPhaseIndex),
                    intro: intro
                )
            }
        }
    }

    private func bossPhaseTitle(phase: Int) -> String {
        switch phase {
        case 1: return "ELE VÊ"
        case 2: return "K̶E̸N̷O̷M̸A̸"
        default: return "FASE \(phase + 1)"
        }
    }

    private func showBossPhaseBanner(title: String, intro: String?) {
        AudioManager.shared.playSFX(AudioTrack.sfxMoralHit)
        damageHaptic += 1
        triggerScreenShake(intensity: 15)

        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
            bossPhaseBannerText = title
            bossPhaseBannerIntro = (intro?.isEmpty == false) ? intro : nil
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            withAnimation(.easeOut(duration: 0.5)) {
                bossPhaseBannerText = nil
                bossPhaseBannerIntro = nil
            }
        }
    }

    @ViewBuilder
    private var bossPhaseBannerOverlay: some View {
        if let title = bossPhaseBannerText {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()

                VStack(spacing: 14) {
                    Text(title)
                        .font(SalvageFont.titleXL(46))
                        .tracking(8)
                        .foregroundStyle(SalvageColor.bloodAccent)
                        .shadow(color: SalvageColor.bloodAccent.opacity(0.7), radius: 12)
                        .changeEffect(.shine, value: title)

                    Rectangle()
                        .fill(SalvageColor.bloodAccent)
                        .frame(width: 80, height: 2)

                    if let intro = bossPhaseBannerIntro {
                        Text(intro)
                            .font(SalvageFont.flavor(14))
                            .italic()
                            .foregroundStyle(SalvageColor.boneWhite.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 60)
                            .frame(maxWidth: 640)
                    }
                }
            }
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Helpers

    private func intentText(for intent: EnemyIntent) -> String {
        switch intent {
        case .attack(let d): return "⚔ \(d)"
        case .multiAttack(let d, let h): return "⚔ \(d)×\(h)"
        case .defend(let b): return "🛡 \(b)"
        case .moralAttack(let d): return "🧠 \(d)"
        case .attackAndMoral(let d, let m): return "⚔\(d) 🧠\(m)"
        case .summon(let c): return "+\(c)"
        case .skip: return "💫"
        }
    }

    private func intentHash(_ intent: EnemyIntent) -> Int {
        switch intent {
        case .attack(let d): return d * 10 + 1
        case .multiAttack(let d, let h): return d * 100 + h * 10 + 2
        case .defend(let b): return b * 10 + 3
        case .moralAttack(let d): return d * 10 + 4
        case .attackAndMoral(let d, let m): return d * 100 + m * 10 + 5
        case .summon(let c): return c * 10 + 6
        case .skip: return 999
        }
    }

    private func statusIcon(_ s: StatusEffect) -> String {
        switch s {
        case .block: return "🛡"
        case .fear: return "👁"
        case .fatigue: return "💤"
        case .corruption: return "🕳"
        case .skipNextTurn: return "⏭"
        }
    }

    private func statusColor(_ s: StatusEffect) -> Color {
        switch s {
        case .block: return SalvageColor.blockBlue.opacity(0.85)
        case .fear: return SalvageColor.moralPurple.opacity(0.85)
        case .fatigue: return .gray.opacity(0.85)
        case .corruption: return SalvageColor.bloodAccent.opacity(0.85)
        case .skipNextTurn: return .orange.opacity(0.85)
        }
    }

    private func effectText(_ effect: CardEffect) -> String {
        switch effect {
        case .damage(let d):
            return String(localized: "combat.damage_short \(d)")
        case .damageAll(let d):
            return String(localized: "combat.damage_all_short \(d)")
        case .damageSelfMoral(let d):
            return String(localized: "combat.damage_self_short \(d)")
        case .gainBlock(let b):
            return String(localized: "combat.block_short \(b)")
        case .gainMoral(let m):
            return String(localized: "combat.moral_short \(m)")
        case .applyStatus(let s, let n):
            return "\(statusIcon(s)) \(n)"
        case .applyStatusAll(let s, let n):
            return "\(statusIcon(s)) \(n)"
        case .exhaustFromHand:
            return String(localized: "combat.exhaust_short")
        case .exhaustChosenFromHand:
            return String(localized: "combat.exhaust_chosen_short")
        case .draw(let n):
            return String(localized: "combat.draw_short \(n)")
        case .skipNextTurn:
            return String(localized: "combat.stun_short")
        case .revealAllIntents:
            return String(localized: "combat.reveal_short")
        }
    }
}
