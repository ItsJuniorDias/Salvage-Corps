//
//  EndingView.swift
//  Salvage Corps
//
//  Tela final. Aparece após vencer o Ato 3 + escolher terminal choice.
//  Usa `bg_endings_*` como background + narrativa longa específica por ending.
//  Botão único no fim: "FIM · Voltar ao menu".
//

import SwiftUI
import Pow
import SalvageCore

struct EndingView: View {

    let ending: EndingPath
    let consequences: ActConsequences
    var onDismiss: () -> Void

    @State private var appeared: Bool = false
    @State private var scrollOpacity: Double = 0

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 24.s) {
                Spacer(minLength: 40.s)

                // Header
                VStack(spacing: 6.s) {
                    Text("ending.header")
                        .font(SalvageFont.label(11))
                        .tracking(8.s)
                        .foregroundStyle(SalvageColor.scarGold)

                    Text(ending.localizedName)
                        .font(SalvageFont.titleXL(38))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .changeEffect(.shine.delay(0.4), value: appeared)
                        .shadow(color: .black.opacity(0.8), radius: 8.s)

                    Rectangle()
                        .fill(SalvageColor.bloodAccent)
                        .frame(width: 80.s, height: 2.s)
                        .padding(.top, 4.s)
                }

                // Narrativa scrollável
                ScrollView {
                    Text(endingText)
                        .font(SalvageFont.body(15))
                        .foregroundStyle(SalvageColor.boneWhite.opacity(0.92))
                        .lineSpacing(7.s)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 60.s)
                        .padding(.vertical, 12.s)
                        .shadow(color: .black.opacity(0.9), radius: 4.s)
                }
                .frame(maxWidth: 720.s, maxHeight: 380.s)
                .opacity(scrollOpacity)

                Spacer()

                // Path breakdown discreto
                VStack(spacing: 6.s) {
                    Text("ending.your_choices")
                        .font(SalvageFont.label(9))
                        .tracking(3.s)
                        .foregroundStyle(.white.opacity(0.55))

                    Text(EndingCalculator.explanation(for: consequences))
                        .font(SalvageFont.caption(10))
                        .foregroundStyle(SalvageColor.scarGold.opacity(0.75))
                }

                // Botão
                Button {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    onDismiss()
                } label: {
                    HStack(spacing: 6.s) {
                        Text("ending.back_to_menu")
                            .font(SalvageFont.label(11))
                            .tracking(2.s)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12.s))
                    }
                    .padding(.horizontal, 28.s)
                    .padding(.vertical, 12.s)
                }
                .buttonStyle(.borderedProminent)
                .tint(SalvageColor.energyOrange)

                Spacer(minLength: 40.s)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appeared = true
            // Fade-in atmosférico do texto após 0.5s
            withAnimation(.easeIn(duration: 1.2).delay(0.5)) {
                scrollOpacity = 1
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Image(backgroundArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            Color.black.opacity(0.72).ignoresSafeArea()
        }
    }

    private var backgroundArt: String {
        switch ending {
        case .complice:   return "bg_endings_complice"
        case .contentor:  return "bg_endings_contentor"
        case .testemunha: return "bg_endings_testemunha"
        case .fugitivo:   return "bg_endings_fugitivo"
        case .espelho:    return "bg_endings_espelho"
        }
    }

    // MARK: - Ending text (localizado via EndingTextStore)

    private var endingText: String {
        EndingTextStore.ending(ending.rawValue)?.endingText ?? fallbackEndingText
    }

    /// Fallback estático (pt-BR curto) caso o store falhe.
    private var fallbackEndingText: String {
        "…"
    }

}
