//
//  UpgradeCardView.swift
//  Salvage Corps
//
//  Escolha de cicatriz: mostra a carta base + 2 caminhos possíveis.
//  Usado dentro do CampView quando player escolhe "Refletir" numa carta.
//

import SwiftUI
import Pow
import SalvageCore

struct UpgradeCardView: View {

    /// Carta base (template ou já com upgrade prévio).
    let baseCard: Card

    /// Os 2 upgrade paths disponíveis.
    let paths: [CardUpgrade]

    /// Callback chamado quando o player escolhe um path.
    var onSelect: (CardUpgrade) -> Void

    /// Callback ao cancelar (X ou tap fora).
    var onCancel: () -> Void

    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            // Fundo escurecido
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 20.s) {
                // Header
                VStack(spacing: 4.s) {
                    Text("upgrade.card_scar_header")
                        .font(SalvageFont.label(11))
                        .tracking(6.s)
                        .foregroundStyle(SalvageColor.energyOrange)

                    Text("upgrade.card_choose_path")
                        .font(SalvageFont.title(20))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .changeEffect(.shine.delay(0.3), value: appeared)
                }

                Rectangle().fill(SalvageColor.bloodAccent).frame(width: 60.s, height: 2.s)

                // Layout: base card à esquerda, seta, 2 paths à direita
                HStack(alignment: .center, spacing: 24.s) {
                    baseCardView

                    Image(systemName: "arrow.right")
                        .font(.system(size: 28.s))
                        .foregroundStyle(SalvageColor.energyOrange.opacity(0.6))

                    VStack(spacing: 14.s) {
                        if paths.indices.contains(0) {
                            pathButton(upgrade: paths[0], label: "PATH A")
                        }
                        if paths.indices.contains(1) {
                            pathButton(upgrade: paths[1], label: "PATH B")
                        }
                    }
                    .frame(maxWidth: 380.s)
                }
                .padding(.horizontal, 24.s)

                // Cancel
                Button {
                    AudioManager.shared.playSFX(AudioTrack.sfxClick)
                    onCancel()
                } label: {
                    Text("upgrade.card_back_no_choice")
                        .font(SalvageFont.label(9))
                        .tracking(2.s)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8.s)
                }
                .buttonStyle(.plain)
            }
            .padding(30.s)
        }
        .preferredColorScheme(.dark)
        .onAppear { appeared = true }
    }

    // MARK: - Base card

    private var baseCardView: some View {
        VStack(spacing: 6.s) {
            Text("upgrade.card_base")
                .font(SalvageFont.label(8))
                .tracking(2.s)
                .foregroundStyle(.white.opacity(0.5))

            cardMiniView(name: baseCard.name, cost: baseCard.cost, effects: baseCard.effects, art: baseCard.artFilename, dimmed: true)

            // Descrição legível do base
            Text(effectsSummary(baseCard.effects))
                .font(SalvageFont.body(9))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(width: 92.s)
                .lineLimit(3)
        }
    }

    // MARK: - Path button

    private func pathButton(upgrade: CardUpgrade, label: String) -> some View {
        Button {
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            onSelect(upgrade)
        } label: {
            HStack(alignment: .center, spacing: 14.s) {
                // Preview mini da versão upgraded
                VStack(spacing: 4.s) {
                    cardMiniView(
                        name: upgrade.name,
                        cost: upgrade.cost ?? baseCard.cost,
                        effects: upgrade.effects ?? baseCard.effects,
                        art: baseCard.artFilename,
                        dimmed: false
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10.s, weight: .bold))
                            .foregroundStyle(SalvageColor.scarGold)
                            .padding(3.s)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .offset(x: 4.s, y: -4.s)
                    }
                }

                // Descrição
                VStack(alignment: .leading, spacing: 6.s) {
                    Text(label)
                        .font(SalvageFont.label(8))
                        .tracking(2.s)
                        .foregroundStyle(SalvageColor.scarGold)

                    Text(upgrade.name)
                        .font(SalvageFont.header(13))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .lineLimit(2)

                    // Diff visualizado: base → upgraded
                    diffView(upgrade: upgrade)

                    if !upgrade.flavorText.isEmpty {
                        Text("\u{201C}\(upgrade.flavorText)\u{201D}")
                            .font(SalvageFont.flavor(9))
                            .italic()
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(3)
                            .padding(.top, 2.s)
                    }
                }

                Spacer(minLength: 0.s)
            }
            .padding(10.s)
            .background(Color.black.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 4.s)
                    .stroke(SalvageColor.scarGold.opacity(0.5), lineWidth: 1.s)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4.s))
        }
        .buttonStyle(.plain)
    }

    /// Mostra o efeito upgraded destacando mudanças em relação ao base.
    private func diffView(upgrade: CardUpgrade) -> some View {
        let effectiveCost = upgrade.cost ?? baseCard.cost
        let costChanged = upgrade.cost != nil && upgrade.cost != baseCard.cost

        return VStack(alignment: .leading, spacing: 3.s) {
            // Cost diff
            if costChanged {
                HStack(spacing: 4.s) {
                    Text("upgrade.card_cost")
                        .font(SalvageFont.body(9))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("\(baseCard.cost)")
                        .font(SalvageFont.number(10))
                        .foregroundStyle(.white.opacity(0.55))
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8.s))
                        .foregroundStyle(SalvageColor.scarGold)
                    Text("\(effectiveCost)")
                        .font(SalvageFont.number(10))
                        .foregroundStyle(SalvageColor.scarGold)
                }
            }

            // Effects
            Text(upgrade.shortDescription)
                .font(SalvageFont.body(10))
                .foregroundStyle(SalvageColor.scarGold)
                .lineLimit(2)
        }
    }

    // MARK: - Effects summary

    /// Converte lista de effects em texto legível pt-BR.
    private func effectsSummary(_ effects: [CardEffect]) -> String {
        effects.map(effectText(_:)).joined(separator: " · ")
    }

    private func effectText(_ effect: CardEffect) -> String {
        switch effect {
        case .damage(let n):
            return String(localized: "effect.damage \(n)")
        case .damageAll(let n):
            return String(localized: "effect.damage_all \(n)")
        case .damageSelfMoral(let n):
            return String(localized: "effect.damage_self_moral \(n)")
        case .gainBlock(let n):
            return String(localized: "effect.gain_block \(n)")
        case .gainMoral(let n):
            return n >= 0
                ? String(localized: "effect.gain_moral \(n)")
                : String(localized: "effect.lose_moral \(n)")
        case .applyStatus(let s, let stacks):
            return String(localized: "effect.status \(statusName(s)) \(stacks)")
        case .applyStatusAll(let s, let stacks):
            return String(localized: "effect.status_all \(statusName(s)) \(stacks)")
        case .exhaustFromHand:
            return String(localized: "effect.exhaust")
        case .exhaustChosenFromHand:
            return String(localized: "effect.exhaust_chosen")
        case .draw(let n):
            return String(localized: "effect.draw \(n)")
        case .skipNextTurn:
            return String(localized: "effect.stun")
        case .revealAllIntents:
            return String(localized: "effect.reveal_intents")
        }
    }

    private func statusName(_ status: StatusEffect) -> String {
        switch status {
        case .block:         return String(localized: "status.block")
        case .fear:          return String(localized: "status.fear")
        case .fatigue:       return String(localized: "status.fatigue")
        case .corruption:    return String(localized: "status.corruption")
        case .skipNextTurn:  return String(localized: "status.skip_next_turn")
        }
    }

    // MARK: - Mini card

    private func cardMiniView(name: String, cost: Int, effects: [CardEffect], art: String?, dimmed: Bool) -> some View {
        VStack(spacing: 0.s) {
            HStack(spacing: 4.s) {
                Text("\(cost)")
                    .font(SalvageFont.number(10))
                    .foregroundStyle(.white)
                    .frame(width: 18.s, height: 18.s)
                    .background(Circle().fill(SalvageColor.energyOrange))
                Text(name)
                    .font(SalvageFont.header(9))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0.s)
            }
            .padding(4.s)
            .background(Color.black.opacity(0.85))

            if let art {
                Image(art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 92.s, height: 66.s)
                    .clipped()
            } else {
                Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 92.s, height: 66.s)
            }
        }
        .frame(width: 92.s)
        .overlay(
            RoundedRectangle(cornerRadius: 3.s)
                .stroke(SalvageColor.boneWhite.opacity(0.3), lineWidth: 1.s)
        )
        .clipShape(RoundedRectangle(cornerRadius: 3.s))
        .opacity(dimmed ? 0.55 : 1.0)
    }
}
