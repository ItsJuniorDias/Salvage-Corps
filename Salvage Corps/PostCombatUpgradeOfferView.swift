//
//  PostCombatUpgradeOfferView.swift
//  Salvage Corps
//
//  Aparece após vitória em combate normal (~30% chance).
//  Player pode escolher aplicar cicatriz numa carta aleatória disponível,
//  ou pular sem aplicar.
//

import SwiftUI
import Pow
import SalvageCore

struct PostCombatUpgradeOfferView: View {

    let card: Card
    let paths: [CardUpgrade]
    var onApply: (CardUpgrade) -> Void
    var onSkip: () -> Void

    @State private var showingUpgrade: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            if showingUpgrade {
                UpgradeCardView(
                    baseCard: card,
                    paths: paths,
                    onSelect: { upgrade in
                        onApply(upgrade)
                    },
                    onCancel: {
                        onSkip()
                    }
                )
                .transition(.opacity)
            } else {
                offerScreen
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { appeared = true }
    }

    private var offerScreen: some View {
        VStack(spacing: 20.s) {
            Spacer()

            Text("post_combat.header")
                .font(SalvageFont.label(11))
                .tracking(6.s)
                .foregroundStyle(SalvageColor.scarGold)

            Text("post_combat.title")
                .font(SalvageFont.title(24))
                .foregroundStyle(SalvageColor.boneWhite)
                .changeEffect(.shine.delay(0.3), value: appeared)

            Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s)

            Text("\u{201C}Você olha pra sua mão. Percebe algo sobre \(card.localizedName.uppercased()). Algo que poderia fazer diferente.\u{201D}")
                .font(SalvageFont.flavor(14))
                .italic()
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60.s)
                .lineSpacing(4.s)

            Spacer()

            HStack(spacing: 16.s) {
                Button {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    onSkip()
                } label: {
                    Text("common.skip")
                        .font(SalvageFont.label(10))
                        .tracking(2.s)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 24.s)
                        .padding(.vertical, 10.s)
                        .background(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4.s)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.s)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4.s))
                }
                .buttonStyle(.plain)

                Button {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    withAnimation { showingUpgrade = true }
                } label: {
                    HStack(spacing: 6.s) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12.s))
                        Text("post_combat.reflect_button")
                            .font(SalvageFont.label(11))
                            .tracking(2.s)
                    }
                    .foregroundStyle(SalvageColor.boneWhite)
                    .padding(.horizontal, 24.s)
                    .padding(.vertical, 10.s)
                    .background(SalvageColor.scarGold.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 4.s))
                    .shadow(color: SalvageColor.scarGold.opacity(0.4), radius: 6.s)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}
