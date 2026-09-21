//
//  DialogueView.swift
//  Salvage Corps
//
//  UI de conversa com NPC. Layout landscape:
//  - Esquerda: retrato do NPC + nome + role
//  - Direita: texto atual + botão "Continuar" pra próxima linha
//  - No fim das linhas: botão "Fechar" retorna pro camp
//

import SwiftUI
import Pow
import SalvageCore

struct DialogueView: View {

    let dialogue: Dialogue
    var onEnd: () -> Void

    @State private var currentLineIndex: Int = 0
    @State private var textAppeared: Bool = false

    private var currentLine: DialogueLine? {
        guard currentLineIndex < dialogue.lines.count else { return nil }
        return dialogue.lines[currentLineIndex]
    }

    private var isLastLine: Bool {
        currentLineIndex >= dialogue.lines.count - 1
    }

    var body: some View {
        ZStack {
            // Fundo escuro atmosférico
            Color.black.opacity(0.95).ignoresSafeArea()

            Image("bg_camp")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.15)

            HStack(alignment: .center, spacing: 32.s) {
                portraitColumn.frame(maxWidth: 260.s)
                dialogueColumn.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 40.s)
            .padding(.vertical, 24.s)
        }
        .preferredColorScheme(.dark)
        .onTapGesture {
            advanceOrEnd()
        }
    }

    // MARK: - Portrait

    private var portraitColumn: some View {
        VStack(alignment: .leading, spacing: 12.s) {
            Spacer()

            Image(dialogue.npc.artFilename)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 280.s)
                .clipShape(RoundedRectangle(cornerRadius: 4.s))
                .overlay(
                    RoundedRectangle(cornerRadius: 4.s)
                        .stroke(SalvageColor.boneWhite.opacity(0.3), lineWidth: 1.s)
                )
                .shadow(color: .black.opacity(0.6), radius: 8.s, y: 4)

            Text(dialogue.npc.name)
                .font(SalvageFont.title(18))
                .foregroundStyle(SalvageColor.boneWhite)

            Text(dialogue.npc.role.uppercased())
                .font(SalvageFont.label(9))
                .tracking(2.s)
                .foregroundStyle(SalvageColor.energyOrange.opacity(0.85))

            Spacer()
        }
    }

    // MARK: - Dialogue text

    private var dialogueColumn: some View {
        VStack(alignment: .leading, spacing: 16.s) {
            Spacer()

            if let line = currentLine {
                VStack(alignment: .leading, spacing: 8.s) {
                    // Speaker header
                    Text(line.speaker)
                        .font(SalvageFont.label(10))
                        .tracking(3.s)
                        .foregroundStyle(speakerColor(line.speaker))

                    Rectangle()
                        .fill(speakerColor(line.speaker))
                        .frame(width: 40.s, height: 1.s)

                    // Corpo do texto
                    Text(line.text)
                        .font(isNarrator(line.speaker) ? SalvageFont.flavor(15) : SalvageFont.body(15))
                        .italic(isNarrator(line.speaker))
                        .foregroundStyle(isNarrator(line.speaker)
                            ? .white.opacity(0.7)
                            : SalvageColor.boneWhite
                        )
                        .lineSpacing(5.s)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id(currentLineIndex)  // força re-render + transition
                        .changeEffect(.shine.delay(0.1), value: currentLineIndex)
                }
                .padding(.vertical, 20.s)
                .padding(.horizontal, 24.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 4.s)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.s)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4.s))
            }

            // Progresso + botão
            HStack {
                // Progress dots
                HStack(spacing: 4.s) {
                    ForEach(0..<dialogue.lines.count, id: \.self) { i in
                        Circle()
                            .fill(i <= currentLineIndex ? SalvageColor.energyOrange : Color.white.opacity(0.2))
                            .frame(width: 6.s, height: 6.s)
                    }
                }

                Spacer()

                Button {
                    advanceOrEnd()
                } label: {
                    HStack(spacing: 6.s) {
                        Text(isLastLine ? "common.close" : "common.continue")
                            .font(SalvageFont.label(10))
                            .tracking(1.5.s)
                        Image(systemName: isLastLine ? "xmark" : "arrow.right")
                            .font(.system(size: 12.s))
                    }
                    .foregroundStyle(SalvageColor.boneWhite)
                    .padding(.horizontal, 14.s)
                    .padding(.vertical, 8.s)
                    .background(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.s)
                            .stroke(SalvageColor.energyOrange.opacity(0.6), lineWidth: 1.s)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4.s))
                }
                .buttonStyle(.plain)
            }

            Text("dialogue.tap_hint")
                .font(SalvageFont.caption(9))
                .foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
        }
    }

    // MARK: - Actions

    private func advanceOrEnd() {
        AudioManager.shared.playSFX(AudioTrack.sfxClick)
        if isLastLine {
            onEnd()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentLineIndex += 1
            }
        }
    }

    // MARK: - Speaker styling

    private func isNarrator(_ speaker: String) -> Bool {
        speaker.uppercased() == "NARRADOR"
    }

    private func speakerColor(_ speaker: String) -> Color {
        if isNarrator(speaker) {
            return .white.opacity(0.5)
        }
        if speaker.uppercased() == "EDMUND" {
            return SalvageColor.bloodAccent
        }
        return SalvageColor.energyOrange
    }
}
