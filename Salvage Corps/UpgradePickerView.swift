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

            VStack(spacing: 16.s) {
                Text("upgrade.picker_title")
                    .font(SalvageFont.label(11))
                    .tracking(4.s)
                    .foregroundStyle(SalvageColor.energyOrange)

                Text("upgrade.picker_subtitle")
                    .font(SalvageFont.body(11))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40.s)

                Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s)

                // Grid horizontal scrollável das cartas
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10.s) {
                        ForEach(templates) { template in
                            cardButton(template)
                        }
                    }
                    .padding(.horizontal, 20.s)
                    .padding(.vertical, 8.s)
                }
                .frame(height: 200.s)

                Button {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    onCancel()
                } label: {
                    Text("common.cancel")
                        .font(SalvageFont.label(10))
                        .tracking(2.s)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 6.s)
                }
                .buttonStyle(.plain)
            }
            .padding(24.s)
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
            VStack(spacing: 0.s) {
                HStack(spacing: 4.s) {
                    Text("\(card.cost)")
                        .font(SalvageFont.number(11))
                        .foregroundStyle(.white)
                        .frame(width: 18.s, height: 18.s)
                        .background(Circle().fill(SalvageColor.energyOrange))
                    Text(card.localizedName)
                        .font(SalvageFont.header(9))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0.s)
                }
                .padding(4.s)
                .background(Color.black.opacity(0.85))

                if let art = card.artFilename {
                    Image(art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100.s, height: 90.s)
                        .clipped()
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 100.s, height: 90.s)
                }

                // Status
                Text(hasUpgrade ? "upgrade.with_scar" : "upgrade.without_scar")
                    .font(SalvageFont.label(7))
                    .tracking(1.s)
                    .foregroundStyle(hasUpgrade ? SalvageColor.energyOrange : .white.opacity(0.4))
                    .padding(.vertical, 3.s)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.75))
            }
            .frame(width: 100.s)
            .overlay(
                RoundedRectangle(cornerRadius: 4.s)
                    .stroke(
                        hasUpgrade ? SalvageColor.energyOrange : SalvageColor.boneWhite.opacity(0.3),
                        lineWidth: hasUpgrade ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4.s))
        }
        .buttonStyle(.plain)
    }
}
