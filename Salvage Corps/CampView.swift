//
//  CampView.swift
//  Salvage Corps
//
//  Tela de acampamento entre combates. Sessão 2 completa.
//
//  3 ações:
//  1. Repousar — cura 30% HP + 20% Moral (1x por camp)
//  2. Refletir — placeholder (Sessão 3 vai ser sistema de cicatrizes)
//  3. Conversar — abre picker de NPCs disponíveis → DialogueView
//

import SwiftUI
import Pow
import SalvageCore

struct CampView: View {

    let node: MapNode
    @Bindable var mapStore: MapStore
    @Bindable var progressStore: ProgressStore
    var onLeave: () -> Void

    @State private var appeared: Bool = false
    @State private var showNPCPicker: Bool = false
    @State private var activeDialogue: Dialogue? = nil
    @State private var restJustUsed: Bool = false
    @State private var lastHealHP: Int = 0
    @State private var lastHealMoral: Int = 0

    // Upgrade / Refletir flow
    @State private var showUpgradePicker: Bool = false
    @State private var upgradingCard: Card? = nil

    // NPCs disponíveis neste camp (determinístico por nó).
    // Henry aparece SEMPRE no Ato 3 (aparição especial fora do pool normal).
    private var availableNPCs: [NPC] {
        var pool = DialogueEngine.shared.availableNPCs(
            forNodeID: node.id,
            act: mapStore.currentAct
        )
        if mapStore.currentAct == 3 && !pool.contains(.henry) {
            pool.append(.henry)
        }
        return pool
    }

    private var restAvailable: Bool {
        mapStore.isRestAvailable(atNodeID: node.id)
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if let dialogue = activeDialogue {
                DialogueView(dialogue: dialogue) {
                    // Ao fechar diálogo, marca como usado e volta pro camp
                    mapStore.markDialogueUsed(nodeID: node.id, npc: dialogue.npc)
                    withAnimation { activeDialogue = nil }
                }
                .transition(.opacity)
            } else if let cardToUpgrade = upgradingCard {
                UpgradeCardView(
                    baseCard: cardToUpgrade,
                    paths: UpgradeCatalog.upgrades(for: cardToUpgrade.templateID ?? ""),
                    onSelect: { upgrade in
                        handleUpgradeSelected(templateID: cardToUpgrade.templateID ?? "", upgrade: upgrade)
                    },
                    onCancel: {
                        withAnimation { upgradingCard = nil }
                    }
                )
                .transition(.opacity)
            } else if showUpgradePicker {
                UpgradePickerView(
                    mapStore: mapStore,
                    onSelect: { card in
                        withAnimation {
                            showUpgradePicker = false
                            upgradingCard = card
                        }
                    },
                    onCancel: {
                        withAnimation { showUpgradePicker = false }
                    }
                )
                .transition(.opacity)
            } else {
                campMainLayout
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { appeared = true }
        .confirmationDialog(
            "camp.talk_picker_title",
            isPresented: $showNPCPicker,
            titleVisibility: .visible
        ) {
            ForEach(availableNPCs) { npc in
                if mapStore.isDialogueAvailable(atNodeID: node.id, npc: npc) {
                    Button(npc.name) {
                        AudioManager.shared.playSFX(AudioTrack.sfxClick)
                        openDialogue(with: npc)
                    }
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            let available = availableNPCs.filter {
                mapStore.isDialogueAvailable(atNodeID: node.id, npc: $0)
            }
            Text(available.isEmpty
                ? "camp.talk_picker_message_none"
                : "camp.talk_picker_message_choose"
            )
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Image("bg_camp")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            Color.black.opacity(0.55).ignoresSafeArea()
        }
    }

    // MARK: - Main layout

    private var campMainLayout: some View {
        HStack(alignment: .center, spacing: 32) {
            leftColumn.frame(maxWidth: .infinity)
            rightColumn.frame(width: 320)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }

    // MARK: - Left column: narrative + player state

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()

            Text("camp.title")
                .font(SalvageFont.label(11))
                .tracking(6)
                .foregroundStyle(SalvageColor.energyOrange)

            Text("camp.subtitle")
                .font(SalvageFont.title(24))
                .foregroundStyle(SalvageColor.boneWhite)
                .changeEffect(.shine.delay(0.3), value: appeared)

            Rectangle()
                .fill(SalvageColor.bloodAccent)
                .frame(width: 60, height: 2)
                .padding(.vertical, 4)

            Text("camp.flavor")
                .font(SalvageFont.flavor(13))
                .italic()
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(4)
                .padding(.trailing, 20)

            Spacer()

            playerStateBox
        }
    }

    private var playerStateBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("camp.your_state")
                .font(SalvageFont.label(9))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))

            statBar(
                label: "HP",
                current: mapStore.runPlayerState.hp,
                max: mapStore.runPlayerState.maxHP,
                color: SalvageColor.bloodAccent,
                healFloat: lastHealHP
            )

            statBar(
                label: "MORAL",
                current: mapStore.runPlayerState.moral,
                max: mapStore.runPlayerState.maxMoral,
                color: SalvageColor.moralPurple,
                healFloat: lastHealMoral
            )
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func statBar(
        label: String,
        current: Int,
        max: Int,
        color: Color,
        healFloat: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(SalvageFont.label(9))
                    .tracking(2)
                    .foregroundStyle(SalvageColor.boneWhite)
                Spacer()
                Text("\(current)/\(max)")
                    .font(SalvageFont.number(11))
                    .foregroundStyle(SalvageColor.boneWhite)

                if healFloat > 0 {
                    Text("+\(healFloat)")
                        .font(SalvageFont.number(11))
                        .foregroundStyle(SalvageColor.energyOrange)
                        .transition(.movingParts.pop(.orange))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.black.opacity(0.6))
                    Rectangle()
                        .fill(color)
                        .frame(width: max > 0
                            ? geo.size.width * CGFloat(current) / CGFloat(max)
                            : 0
                        )
                        .animation(.spring(response: 0.6), value: current)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: - Right column: actions

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()

            Text("camp.available_actions")
                .font(SalvageFont.label(10))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 4)

            actionButton(
                icon: "bed.double.fill",
                title: "camp.rest",
                subtitle: "camp.rest_subtitle",
                enabled: restAvailable,
                usedLabel: "camp.rest_used"
            ) {
                handleRest()
            }

            actionButton(
                icon: "sparkles",
                title: "camp.reflect",
                subtitle: reflectSubtitle,
                enabled: reflectAvailable,
                usedLabel: "camp.reflect_used"
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                withAnimation { showUpgradePicker = true }
            }

            actionButton(
                icon: "bubble.left.and.bubble.right.fill",
                title: "camp.talk",
                subtitle: dialoguesAvailableCount > 0
                    ? "camp.talk_npcs_available \(dialoguesAvailableCount)"
                    : "camp.talk_no_one",
                enabled: dialoguesAvailableCount > 0,
                usedLabel: "camp.talk_no_one_hint"
            ) {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                showNPCPicker = true
            }

            Spacer()

            Button {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                onLeave()
            } label: {
                HStack(spacing: 6) {
                    Text("camp.move_on")
                        .font(SalvageFont.label(11))
                        .tracking(2)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(SalvageColor.energyOrange)
            .frame(maxWidth: .infinity)
        }
    }

    private var dialoguesAvailableCount: Int {
        availableNPCs.filter { mapStore.isDialogueAvailable(atNodeID: node.id, npc: $0) }.count
    }

    // MARK: - Action button

    private func actionButton(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        enabled: Bool,
        usedLabel: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(enabled ? SalvageColor.energyOrange : .white.opacity(0.3))
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SalvageFont.header(14))
                        .foregroundStyle(enabled ? SalvageColor.boneWhite : .white.opacity(0.4))

                    Text(enabled ? subtitle : usedLabel)
                        .font(SalvageFont.body(10))
                        .foregroundStyle(enabled ? .white.opacity(0.65) : .white.opacity(0.35))
                }

                Spacer()

                if !enabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.3))
                        .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(enabled ? 0.65 : 0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        enabled ? SalvageColor.energyOrange.opacity(0.4) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Actions

    private func handleRest() {
        let previousHP = mapStore.runPlayerState.hp
        let previousMoral = mapStore.runPlayerState.moral

        let applied = mapStore.restAtCurrentCamp()
        guard applied else { return }

        let newHP = mapStore.runPlayerState.hp
        let newMoral = mapStore.runPlayerState.moral

        withAnimation(.spring(response: 0.4)) {
            lastHealHP = newHP - previousHP
            lastHealMoral = newMoral - previousMoral
            restJustUsed = true
        }

        AudioManager.shared.playSFX(AudioTrack.sfxCardDraw)  // usar sfx suave

        // Limpa floating text depois de 2s
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation { lastHealHP = 0; lastHealMoral = 0 }
            }
        }
    }

    private func openDialogue(with npc: NPC) {
        guard let dialogue = DialogueEngine.shared.pickDialogue(
            for: npc,
            act: mapStore.currentAct,
            atNodeID: node.id
        ) else {
            print("CampView: nenhum diálogo disponível pra \(npc)")
            return
        }
        // Meta layer: se é Henry, registra encounter (condição do Espelho)
        if npc == .henry {
            progressStore.recordHenryEncounter()
        }
        withAnimation { activeDialogue = dialogue }
    }

    // MARK: - Refletir (upgrade de cartas)

    private var reflectAvailable: Bool {
        !mapStore.usedCampActions.contains("\(node.id.uuidString):reflect")
    }

    private var reflectSubtitle: LocalizedStringKey {
        let count = mapStore.playerDeck.upgradeCount
        return count == 0
            ? "camp.reflect_default_subtitle"
            : "camp.reflect_scars_applied \(count)"
    }

    private func handleUpgradeSelected(templateID: String, upgrade: CardUpgrade) {
        mapStore.applyCardUpgrade(templateID: templateID, upgradeID: upgrade.id)
        // Marca reflect como usado neste camp
        markReflectUsed()
        AudioManager.shared.playSFX(AudioTrack.sfxVictory)
        withAnimation {
            upgradingCard = nil
        }
    }

    private func markReflectUsed() {
        // Piggy-back no usedCampActions do MapStore usando key "reflect"
        // Precisa expor isso — por enquanto criamos a key na hora do check
        // e o método markDialogueUsed foi generalizado no MapStore… hmm,
        // por simplicidade, faz o mesmo padrão manual:
        _ = mapStore.markReflectUsed(nodeID: node.id)
    }
}
