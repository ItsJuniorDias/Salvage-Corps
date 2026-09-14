//
//  DeckBuilderView.swift
//  Salvage Corps
//
//  Fase 8: construtor de deck PvP. Grid de 8 templates com controles -/+/count,
//  header com N/15, salvar/resetar.
//

import SwiftUI
import SalvageCore

struct DeckBuilderView: View {

    @Bindable var deckStore: DeckStore
    var onBack: () -> Void

    // Working copy — só persiste no DeckStore quando o user clica Salvar
    @State private var workingDeck: DuelDeckConfig
    @State private var savedFlash: Bool = false

    init(deckStore: DeckStore, onBack: @escaping () -> Void) {
        self.deckStore = deckStore
        self.onBack = onBack
        _workingDeck = State(initialValue: deckStore.currentDeck)
    }

    var body: some View {
        ZStack {
            Image("bg_trench")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.7))

            ScrollView {
                VStack(spacing: 20) {
                    header.padding(.top, 20)
                    countBadge
                    templatesGrid
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .topLeading) {
            backButton.padding()
        }
        .overlay(alignment: .top) {
            if savedFlash {
                Text("duel.deck.saved_toast")
                    .font(SalvageFont.label(11))
                    .tracking(3)
                    .foregroundStyle(SalvageColor.boneWhite)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(SalvageColor.energyOrange.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("duel.deck.builder_title")
                .font(SalvageFont.titleXL(32))
                .foregroundStyle(SalvageColor.boneWhite)
                .tracking(6)
            Rectangle().fill(SalvageColor.energyOrange).frame(width: 40, height: 2)
            Text("duel.deck.builder_subtitle")
                .font(SalvageFont.label(9))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(3)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Count badge

    private var countBadge: some View {
        let total = workingDeck.totalCards
        let isValid = total == DuelDeckConfig.deckSize
        return HStack(spacing: 12) {
            Text("duel.deck.count_label \(total) \(DuelDeckConfig.deckSize)")
                .font(SalvageFont.header(20))
                .foregroundStyle(isValid ? SalvageColor.energyOrange : SalvageColor.bloodAccent)
                .tracking(3)

            if !isValid {
                Text(total < DuelDeckConfig.deckSize
                     ? LocalizedStringKey("duel.deck.need_more \(DuelDeckConfig.deckSize - total)")
                     : LocalizedStringKey("duel.deck.need_less \(total - DuelDeckConfig.deckSize)"))
                    .font(SalvageFont.body(11))
                    .foregroundStyle(SalvageColor.bloodAccent.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isValid ? SalvageColor.energyOrange.opacity(0.4) : SalvageColor.bloodAccent.opacity(0.5),
                        lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Templates grid

    private var templatesGrid: some View {
        let templates = StarterDeck.uniqueTemplates()
        let templateByID: [String: Card] = Dictionary(
            uniqueKeysWithValues: templates.compactMap { t in
                t.templateID.map { ($0, t) }
            }
        )
        return VStack(alignment: .leading, spacing: 8) {
            Text("duel.deck.pool_title")
                .font(SalvageFont.label(9))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(DuelDeckConfig.allowedTemplates, id: \.self) { tid in
                    if let template = templateByID[tid] {
                        templateRow(template: template, templateID: tid)
                    }
                }
            }
        }
    }

    private func templateRow(template: Card, templateID: String) -> some View {
        let count = workingDeck.count(for: templateID)
        let atMax = count >= DuelDeckConfig.maxCopiesPerTemplate

        return HStack(spacing: 10) {
            // Card mini-preview
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(template.cost)")
                        .font(SalvageFont.number(11))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(SalvageColor.energyOrange))
                    Text(template.localizedName)
                        .font(SalvageFont.header(11))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(effectSummary(template.effects))
                    .font(SalvageFont.body(9))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Counter controls
            HStack(spacing: 6) {
                Button {
                    workingDeck.decrement(templateID)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(count > 0 ? SalvageColor.bloodAccent.opacity(0.85) : .gray.opacity(0.4))
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(count == 0)

                Text("\(count)")
                    .font(SalvageFont.number(14))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .frame(width: 18)

                Button {
                    workingDeck.increment(templateID)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(atMax ? .gray.opacity(0.4) : SalvageColor.energyOrange.opacity(0.85))
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(atMax)
            }
        }
        .padding(10)
        .background(Color.black.opacity(count > 0 ? 0.55 : 0.35))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(count > 0 ? SalvageColor.energyOrange.opacity(0.35) : Color.white.opacity(0.1),
                        lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        let isValid = workingDeck.isValid
        let hasChanges = workingDeck != deckStore.currentDeck

        return HStack(spacing: 12) {
            Button {
                workingDeck = DuelDeckConfig.starterEdmund
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("duel.deck.reset_default")
                        .font(SalvageFont.label(10))
                        .tracking(2)
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                deckStore.currentDeck = workingDeck
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    savedFlash = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { savedFlash = false }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("duel.deck.save")
                        .font(SalvageFont.label(10))
                        .tracking(2)
                }
                .foregroundStyle(isValid && hasChanges ? SalvageColor.boneWhite : .white.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    isValid && hasChanges
                        ? SalvageColor.energyOrange.opacity(0.85)
                        : Color.black.opacity(0.4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4).stroke(
                        isValid && hasChanges ? SalvageColor.energyOrange : Color.white.opacity(0.15),
                        lineWidth: 1
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .disabled(!isValid || !hasChanges)
        }
    }

    // MARK: - Back

    private var backButton: some View {
        Button {
            onBack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("duel.deck.back")
                    .font(SalvageFont.label(11))
                    .tracking(2)
            }
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .clipShape(Capsule())
        }
    }

    // MARK: - Effect summary (short)

    /// Resume os efeitos de uma carta pra caber em 1-2 linhas na grid.
    private func effectSummary(_ effects: [CardEffect]) -> String {
        effects.map { e -> String in
            switch e {
            case .damage(let d): return String(localized: "combat.damage_short \(d)")
            case .damageAll(let d): return String(localized: "combat.damage_all_short \(d)")
            case .damageSelfMoral(let d): return String(localized: "combat.damage_self_short \(d)")
            case .gainBlock(let b): return String(localized: "combat.block_short \(b)")
            case .gainMoral(let m): return String(localized: "combat.moral_short \(m)")
            case .applyStatus(_, let n): return "+\(n) status"
            case .applyStatusAll(_, let n): return "+\(n) status"
            case .exhaustFromHand: return String(localized: "combat.exhaust_short")
            case .exhaustChosenFromHand: return String(localized: "combat.exhaust_chosen_short")
            case .draw(let n): return String(localized: "combat.draw_short \(n)")
            case .skipNextTurn: return String(localized: "combat.stun_short")
            case .revealAllIntents: return String(localized: "combat.reveal_short")
            }
        }.joined(separator: " · ")
    }
}
