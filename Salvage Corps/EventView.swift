//
//  EventView.swift
//  Salvage Corps
//
//  Tela de eventos narrativos. Sessão 4 completa.
//
//  Fluxo:
//  1. Mostra narrativa + N choices (2-3)
//  2. Player escolhe → aplica effects → mostra resultText
//  3. Botão "Continuar" fecha e volta pro mapa
//
//  Resolução do evento: se node.narrativeID bate com fixed → esse.
//  Senão pool procedural determinístico pelo UUID.
//

import SwiftUI
import Pow
import SalvageCore

struct EventView: View {

    let node: MapNode
    @Bindable var mapStore: MapStore
    var onResolve: () -> Void

    @State private var event: GameEvent?
    @State private var chosenChoice: EventChoice?
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            backgroundLayer

            if let event {
                if let chosen = chosenChoice {
                    resultScreen(event: event, choice: chosen)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    choiceScreen(event: event)
                        .transition(.opacity)
                }
            } else {
                // Fallback — sem evento resolvido pra este nó
                fallbackScreen
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            event = EventCatalog.resolveEvent(
                for: node.narrativeID,
                nodeID: node.id,
                act: mapStore.currentAct
            )
            appeared = true
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            let art = event?.backgroundArt ?? "bg_no_mans_land"
            Image(art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            Color.black.opacity(0.72).ignoresSafeArea()
        }
    }

    // MARK: - Choice screen

    private func choiceScreen(event: GameEvent) -> some View {
        HStack(alignment: .top, spacing: 32) {
            narrativeColumn(event: event).frame(maxWidth: .infinity)
            choicesColumn(event: event).frame(width: 340)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }

    private func narrativeColumn(event: GameEvent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()

            Text("event.header")
                .font(SalvageFont.label(11))
                .tracking(6)
                .foregroundStyle(SalvageColor.energyOrange)

            Text(event.title)
                .font(SalvageFont.title(26))
                .foregroundStyle(SalvageColor.boneWhite)
                .changeEffect(.shine.delay(0.3), value: appeared)

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60, height: 2).padding(.vertical, 6)

            Text(event.narrative)
                .font(SalvageFont.flavor(13))
                .italic()
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(5)
                .padding(.trailing, 20)

            Spacer()
        }
    }

    private func choicesColumn(event: GameEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()

            Text("event.decision")
                .font(SalvageFont.label(10))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 4)

            ForEach(event.choices) { choice in
                choiceButton(choice)
            }

            Spacer()
        }
    }

    private func choiceButton(_ choice: EventChoice) -> some View {
        Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            withAnimation(.easeInOut(duration: 0.35)) {
                mapStore.applyEventEffects(choice.effects)
                chosenChoice = choice
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(choice.label)
                    .font(SalvageFont.header(14))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .multilineTextAlignment(.leading)

                if let hint = choice.costHint {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption2)
                        Text(hint)
                            .font(SalvageFont.body(10))
                    }
                    .foregroundStyle(SalvageColor.energyOrange.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(SalvageColor.energyOrange.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result screen

    private func resultScreen(event: GameEvent, choice: EventChoice) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Text("event.consequence")
                .font(SalvageFont.label(11))
                .tracking(6)
                .foregroundStyle(SalvageColor.bloodAccent)

            Text(choice.label)
                .font(SalvageFont.title(20))
                .foregroundStyle(SalvageColor.boneWhite)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60, height: 2)

            ScrollView {
                Text(choice.resultText)
                    .font(SalvageFont.body(14))
                    .foregroundStyle(SalvageColor.boneWhite.opacity(0.9))
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 8)
            }
            .frame(maxHeight: 240)

            // Effects aplicados como pequenos badges
            if !choice.effects.isEmpty {
                HStack(spacing: 8) {
                    ForEach(choice.effects.indices, id: \.self) { i in
                        effectBadge(choice.effects[i])
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            Button {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                onResolve()
            } label: {
                HStack(spacing: 6) {
                    Text("common.continue")
                        .font(SalvageFont.label(11))
                        .tracking(2)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(SalvageColor.energyOrange)

            Spacer()
        }
    }

    private func effectBadge(_ effect: EventEffect) -> some View {
        let (text, color) = effectBadgeInfo(effect)
        return Text(text)
            .font(SalvageFont.number(11))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func effectBadgeInfo(_ effect: EventEffect) -> (String, Color) {
        switch effect {
        case .gainHP(let n):
            let sign = n >= 0 ? "+" : ""
            return ("\(sign)\(n) HP", n >= 0 ? .green : SalvageColor.hpRed)
        case .gainMoral(let n):
            let sign = n >= 0 ? "+" : ""
            return ("\(sign)\(n) MORAL", n >= 0 ? SalvageColor.moralPurple : SalvageColor.hpRed)
        case .gainMaxHP(let n):
            let sign = n >= 0 ? "+" : ""
            return ("\(sign)\(n) MAX HP", n >= 0 ? .green : SalvageColor.hpRed)
        case .gainMaxMoral(let n):
            let sign = n >= 0 ? "+" : ""
            return ("\(sign)\(n) MAX MORAL", n >= 0 ? SalvageColor.moralPurple : SalvageColor.hpRed)
        case .applyScar:
            return ("★ CICATRIZ", SalvageColor.scarGold)
        case .addCard(let templateID):
            let name = StarterDeck.extraCardTemplate(for: templateID)?.name ?? "CARTA"
            return ("+ \(name.uppercased())", SalvageColor.scarGold)
        }
    }

    // MARK: - Fallback

    private var fallbackScreen: some View {
        VStack(spacing: 16) {
            Text("event.header")
                .font(SalvageFont.label(11))
                .tracking(6)
                .foregroundStyle(SalvageColor.energyOrange)

            Text("event.nothing_happened")
                .font(SalvageFont.body(14))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                onResolve()
            } label: {
                Text("common.continue")
                    .font(SalvageFont.label(11))
                    .tracking(2)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(SalvageColor.energyOrange)
        }
    }
}
