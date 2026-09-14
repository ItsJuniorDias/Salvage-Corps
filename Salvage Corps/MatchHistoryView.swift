//
//  MatchHistoryView.swift
//  Salvage Corps
//
//  Fase 10: histórico dos últimos matches ranked. Lista scrollable com
//  V/D + adversário + tier + delta ELO + tempo relativo ("há 3 dias").
//

import SwiftUI
import SalvageCore

struct MatchHistoryView: View {

    @Bindable var historyStore: MatchHistoryStore
    var onBack: () -> Void

    var body: some View {
        ZStack {
            Image("bg_trench")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.7))

            ScrollView {
                VStack(spacing: 12) {
                    header.padding(.top, 20)
                    if historyStore.entries.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(historyStore.entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("duel.history.title")
                .font(SalvageFont.titleXL(32))
                .foregroundStyle(SalvageColor.boneWhite)
                .tracking(6)
            Rectangle().fill(SalvageColor.energyOrange).frame(width: 40, height: 2)
            Text("duel.history.subtitle \(historyStore.entries.count)")
                .font(SalvageFont.label(9))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(3)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("duel.history.empty_title")
                .font(SalvageFont.header(13))
                .foregroundStyle(.white.opacity(0.6))
            Text("duel.history.empty_message")
                .font(SalvageFont.body(11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Row

    private func entryRow(_ entry: MatchHistoryEntry) -> some View {
        let tier = RatingTier.tier(for: entry.opponentRatingAtStart)
        let winColor: Color = entry.iWon ? SalvageColor.energyOrange : SalvageColor.bloodAccent
        let deltaSign = entry.delta >= 0 ? "+" : ""

        return HStack(spacing: 12) {
            // Ícone V/D
            ZStack {
                Circle()
                    .fill(winColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: entry.iWon ? "checkmark" : "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(winColor)
            }

            // Nome + tier + tempo
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(entry.opponentName)
                        .font(SalvageFont.header(12))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .lineLimit(1)
                    // Tier badge compacto
                    HStack(spacing: 2) {
                        Image(systemName: tier.iconName)
                            .font(.system(size: 7))
                        Text(tier.displayNameKey)
                            .font(SalvageFont.label(7))
                            .tracking(1)
                    }
                    .foregroundStyle(tier.accentColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(tier.accentColor.opacity(0.18))
                    .clipShape(Capsule())
                }
                Text(relativeTime(from: entry.timestamp))
                    .font(SalvageFont.body(9))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Delta rating
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(deltaSign)\(entry.delta)")
                    .font(SalvageFont.number(14))
                    .foregroundStyle(winColor)
                Text("\(entry.myRatingAfter)")
                    .font(SalvageFont.number(10))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(winColor.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Back

    private var backButton: some View {
        Button {
            onBack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("duel.deck.back")  // reusa chave "Duelos"
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

    // MARK: - Time formatting

    /// Formatação relativa: "agora", "há 3 min", "há 2h", "há 3 dias", "há 2 semanas".
    /// Usa RelativeDateTimeFormatter da Apple — respeita locale automaticamente.
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
