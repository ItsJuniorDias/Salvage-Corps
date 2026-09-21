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
        HStack(alignment: .top, spacing: 32.s) {
            narrativeColumn(event: event).frame(maxWidth: .infinity)
            choicesColumn(event: event).frame(width: 340.s)
        }
        .padding(.horizontal, 40.s)
        .padding(.vertical, 24.s)
    }

    private func narrativeColumn(event: GameEvent) -> some View {
        VStack(alignment: .leading, spacing: 14.s) {
            Spacer()

            Text("event.header")
                .font(SalvageFont.label(11))
                .tracking(6.s)
                .foregroundStyle(SalvageColor.energyOrange)

            Text(event.title)
                .font(SalvageFont.title(26))
                .foregroundStyle(SalvageColor.boneWhite)
                .changeEffect(.shine.delay(0.3), value: appeared)

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s).padding(.vertical, 6.s)

            Text(event.narrative)
                .font(SalvageFont.flavor(13))
                .italic()
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(5.s)
                .padding(.trailing, 20.s)

            Spacer()
        }
    }

    private func choicesColumn(event: GameEvent) -> some View {
        VStack(alignment: .leading, spacing: 10.s) {
            Spacer()

            Text("event.decision")
                .font(SalvageFont.label(10))
                .tracking(3.s)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 4.s)

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
            VStack(alignment: .leading, spacing: 6.s) {
                Text(choice.label)
                    .font(SalvageFont.header(14))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .multilineTextAlignment(.leading)

                if let hint = choice.costHint {
                    HStack(spacing: 4.s) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 11.s))
                        Text(hint)
                            .font(SalvageFont.body(10))
                    }
                    .foregroundStyle(SalvageColor.energyOrange.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14.s)
            .padding(.vertical, 12.s)
            .background(Color.black.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 4.s)
                    .stroke(SalvageColor.energyOrange.opacity(0.4), lineWidth: 1.s)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4.s))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result screen

    private func resultScreen(event: GameEvent, choice: EventChoice) -> some View {
        VStack(spacing: 20.s) {
            Spacer()

            Text("event.consequence")
                .font(SalvageFont.label(11))
                .tracking(6.s)
                .foregroundStyle(SalvageColor.bloodAccent)

            Text(choice.label)
                .font(SalvageFont.title(20))
                .foregroundStyle(SalvageColor.boneWhite)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40.s)

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s)

            ScrollView {
                Text(choice.resultText)
                    .font(SalvageFont.body(14))
                    .foregroundStyle(SalvageColor.boneWhite.opacity(0.9))
                    .lineSpacing(6.s)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60.s)
                    .padding(.vertical, 8.s)
            }
            .frame(maxHeight: 240.s)

            // Effects aplicados como pequenos badges
            if !choice.effects.isEmpty {
                HStack(spacing: 8.s) {
                    ForEach(choice.effects.indices, id: \.self) { i in
                        effectBadge(choice.effects[i])
                    }
                }
                .padding(.vertical, 4.s)
            }

            Spacer()

            Button {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                onResolve()
            } label: {
                HStack(spacing: 6.s) {
                    Text("common.continue")
                        .font(SalvageFont.label(11))
                        .tracking(2.s)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12.s))
                }
                .padding(.horizontal, 24.s)
                .padding(.vertical, 12.s)
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
            .tracking(1.s)
            .foregroundStyle(color)
            .padding(.horizontal, 10.s)
            .padding(.vertical, 5.s)
            .background(Color.black.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 3.s)
                    .stroke(color.opacity(0.5), lineWidth: 1.s)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3.s))
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
        VStack(spacing: 16.s) {
            Text("event.header")
                .font(SalvageFont.label(11))
                .tracking(6.s)
                .foregroundStyle(SalvageColor.energyOrange)

            Text("event.nothing_happened")
                .font(SalvageFont.body(14))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                onResolve()
            } label: {
                Text("common.continue")
                    .font(SalvageFont.label(11))
                    .tracking(2.s)
                    .padding(.horizontal, 24.s)
                    .padding(.vertical, 10.s)
            }
            .buttonStyle(.borderedProminent)
            .tint(SalvageColor.energyOrange)
        }
    }
}
