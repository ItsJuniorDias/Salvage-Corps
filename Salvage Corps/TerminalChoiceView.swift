//
//  TerminalChoiceView.swift
//  Salvage Corps
//
//  Escolha narrativa que fecha um ato. Após vencer o boss, player
//  decide COMO reporta o incidente — escolha afeta ending futuro.
//
//  Estrutura similar ao EventView: narrativa → 3 choices → resultText → continua.
//

import SwiftUI
import Pow
import SalvageCore

struct TerminalChoiceView: View {

    /// Qual ato está sendo fechado (1, 2 ou 3).
    let act: Int

    /// Callback ao terminar: retorna a escolha feita pra RootView persistir.
    var onChoice: (TerminalChoice) -> Void

    @State private var chosen: TerminalChoice?
    @State private var appeared: Bool = false

    private var availableChoices: [TerminalChoice] {
        TerminalChoice.allCases.filter { $0.act == act }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if let chosen {
                resultScreen(choice: chosen)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                choiceScreen
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { appeared = true }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Image("bg_no_mans_land")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            Color.black.opacity(0.82).ignoresSafeArea()
        }
    }

    // MARK: - Choice screen

    private var choiceScreen: some View {
        HStack(alignment: .center, spacing: 32.s) {
            narrativeColumn.frame(maxWidth: .infinity)
            choicesColumn.frame(width: 380.s)
        }
        .padding(.horizontal, 40.s)
        .padding(.vertical, 24.s)
    }

    private var narrativeColumn: some View {
        VStack(alignment: .leading, spacing: 14.s) {
            Spacer()

            Text("terminal.act_prefix \(romanNumeral(act))")
                .font(SalvageFont.label(11))
                .tracking(6.s)
                .foregroundStyle(SalvageColor.bloodAccent)

            Text(actTitle)
                .font(SalvageFont.title(30))
                .foregroundStyle(SalvageColor.boneWhite)
                .changeEffect(.shine.delay(0.3), value: appeared)

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s).padding(.vertical, 8.s)

            Text(narrativeText)
                .font(SalvageFont.flavor(14))
                .italic()
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(6.s)
                .padding(.trailing, 20.s)

            Spacer()
        }
    }

    private var choicesColumn: some View {
        VStack(alignment: .leading, spacing: 12.s) {
            Spacer()

            Text("terminal.your_decision")
                .font(SalvageFont.label(10))
                .tracking(3.s)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 4.s)

            ForEach(availableChoices) { choice in
                choiceButton(choice)
            }

            Spacer()
        }
    }

    private func choiceButton(_ choice: TerminalChoice) -> some View {
        Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            withAnimation(.easeInOut(duration: 0.4)) {
                chosen = choice
            }
        } label: {
            VStack(alignment: .leading, spacing: 6.s) {
                Text(choiceLabel(choice))
                    .font(SalvageFont.header(14))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .multilineTextAlignment(.leading)

                Text(choiceCostHint(choice))
                    .font(SalvageFont.body(10))
                    .foregroundStyle(SalvageColor.bloodAccent.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14.s)
            .padding(.vertical, 14.s)
            .background(Color.black.opacity(0.75))
            .overlay(
                RoundedRectangle(cornerRadius: 4.s)
                    .stroke(SalvageColor.bloodAccent.opacity(0.5), lineWidth: 1.s)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4.s))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result screen

    private func resultScreen(choice: TerminalChoice) -> some View {
        VStack(spacing: 22.s) {
            Spacer()

            Text("terminal.consequence")
                .font(SalvageFont.label(11))
                .tracking(6.s)
                .foregroundStyle(SalvageColor.bloodAccent)

            Text(choiceLabel(choice))
                .font(SalvageFont.title(22))
                .foregroundStyle(SalvageColor.boneWhite)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40.s)

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s)

            ScrollView {
                Text(choiceResult(choice))
                    .font(SalvageFont.body(14))
                    .foregroundStyle(SalvageColor.boneWhite.opacity(0.9))
                    .lineSpacing(6.s)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60.s)
                    .padding(.vertical, 8.s)
            }
            .frame(maxHeight: 260.s)

            // Ending path badge
            HStack(spacing: 8.s) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12.s))
                Text("terminal.path_label \(choice.endingInfluence.localizedName.uppercased())")
                    .font(SalvageFont.label(10))
                    .tracking(2.s)
            }
            .foregroundStyle(SalvageColor.scarGold)
            .padding(.horizontal, 14.s)
            .padding(.vertical, 7.s)
            .background(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 3.s)
                    .stroke(SalvageColor.scarGold.opacity(0.5), lineWidth: 1.s)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3.s))

            Spacer()

            Button {
                AudioManager.shared.playSFX(AudioTrack.sfxClick)
                onChoice(choice)
            } label: {
                HStack(spacing: 6.s) {
                    Text("terminal.act_prefix \(romanNumeral(act))")
                        .font(SalvageFont.label(11))
                        .tracking(2.s)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12.s))
                }
                .padding(.horizontal, 26.s)
                .padding(.vertical, 12.s)
            }
            .buttonStyle(.borderedProminent)
            .tint(SalvageColor.energyOrange)

            Spacer()
        }
    }

    // MARK: - Content lookup (localizado via TerminalTextStore)

    private var actTitle: String {
        TerminalTextStore.act(act)?.title ?? fallbackActTitle
    }

    private var narrativeText: String {
        TerminalTextStore.act(act)?.narrative ?? "…"
    }

    private func choiceLabel(_ choice: TerminalChoice) -> String {
        TerminalTextStore.choice(choice.rawValue)?.label ?? choice.rawValue
    }

    private func choiceCostHint(_ choice: TerminalChoice) -> String {
        TerminalTextStore.choice(choice.rawValue)?.costHint ?? ""
    }

    private func choiceResult(_ choice: TerminalChoice) -> String {
        TerminalTextStore.choice(choice.rawValue)?.resultText ?? "…"
    }

    /// Fallback estático pra actTitle caso o store não tenha carregado.
    private var fallbackActTitle: String {
        switch act {
        case 1: return "Hauptmann Krüger caiu"
        case 2: return "O Apóstolo já não respira"
        case 3: return "O Arquivo do Corps"
        default: return ""
        }
    }


    private func romanNumeral(_ n: Int) -> String {
        switch n {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        default: return "\(n)"
        }
    }
}
