//
//  UpgradePickerView.swift
//  Salvage Corps
//
//  Sheet mostrando os 10 templates de carta pra o player escolher qual upgradear.
//  Cartas já upgraded ficam visualmente marcadas.
//

import SwiftUI
import SalvageCore

struct UpgradePickerView: View {

    @Bindable var mapStore: MapStore

    /// Callback quando escolhe uma carta template pra upgradear.
    var onSelect: (Card) -> Void

    /// Callback ao cancelar.
    var onCancel: () -> Void

    private var templates: [Card] {
        StarterDeck.uniqueTemplates(with: mapStore.playerDeck)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 16) {
                Text("upgrade.picker_title")
                    .font(SalvageFont.label(11))
                    .tracking(4)
                    .foregroundStyle(SalvageColor.energyOrange)

                Text("upgrade.picker_subtitle")
                    .font(SalvageFont.body(11))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60, height: 2)

                // Grid horizontal scrollável das cartas
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(templates) { template in
                            cardButton(template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .frame(height: 200)

                Button {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    onCancel()
                } label: {
                    Text("common.cancel")
                        .font(SalvageFont.label(10))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Card button

    private func cardButton(_ card: Card) -> some View {
        let hasUpgrade = card.templateID.map { mapStore.playerDeck.hasUpgrade(templateID: $0) } ?? false

        return Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            onSelect(card)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("\(card.cost)")
                        .font(SalvageFont.number(11))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(SalvageColor.energyOrange))
                    Text(card.localizedName)
                        .font(SalvageFont.header(9))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                .padding(4)
                .background(Color.black.opacity(0.85))

                if let art = card.artFilename {
                    Image(art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 90)
                        .clipped()
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 100, height: 90)
                }

                // Status
                Text(hasUpgrade ? "upgrade.with_scar" : "upgrade.without_scar")
                    .font(SalvageFont.label(7))
                    .tracking(1)
                    .foregroundStyle(hasUpgrade ? SalvageColor.energyOrange : .white.opacity(0.4))
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.75))
            }
            .frame(width: 100)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        hasUpgrade ? SalvageColor.energyOrange : SalvageColor.boneWhite.opacity(0.3),
                        lineWidth: hasUpgrade ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
