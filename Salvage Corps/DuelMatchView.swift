//
//  DuelMatchView.swift
//  Salvage Corps
//
//  Fase 5 + 5.5 + i18n: UI de combate PvP jogável, polida e localizada.
//  Strings via Localizable.xcstrings (pt-BR, en, es).
//

import SwiftUI
import GameKit
import Pow
import SalvageCore
import UIKit

struct DuelMatchView: View {

    @Bindable var store: DuelMatchStore
    var onBack: () -> Void

    @State private var selectedCardIndex: Int? = nil
    @State private var showForfeitConfirm: Bool = false
    @State private var actionError: String?
    @State private var showLog: Bool = false
    @State private var cardShakeTriggers: [UUID: Int] = [:]

    // Tracking pra floating numbers e flashes
    @State private var lastMyHP: Int = -1
    @State private var lastOppHP: Int = -1
    @State private var lastMyMoral: Int = -1
    @State private var lastOppMoral: Int = -1
    @State private var lastMyBlock: Int = -1
    @State private var lastOppBlock: Int = -1

    @State private var myHPFloatingValue: Int = 0
    @State private var oppHPFloatingValue: Int = 0
    @State private var myMoralFloatingValue: Int = 0
    @State private var oppMoralFloatingValue: Int = 0
    @State private var myBlockFloatingValue: Int = 0
    @State private var oppBlockFloatingValue: Int = 0

    @State private var damageFlashOpacity: Double = 0
    @State private var damageFlashColor: Color = .red

    @State private var showTurnBanner: Bool = false
    @State private var turnBannerKey: LocalizedStringKey = ""
    @State private var lastIsMyTurn: Bool? = nil

    @State private var showRecap: Bool = false
    @State private var lastPreviousTurnEventsCount: Int = -1

    var body: some View {
        ZStack {
            Image("bg_trench")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.6))

            if let state = store.duelState {
                if state.phase == .awaitingOpponentDeck {
                    // Fase 8: setup PvP. Host acabou de criar, oponente ainda
                    // não abriu ou não submeteu deck. Se sou o oponente, o
                    // auto-submit já rodou (deve ser instantâneo).
                    awaitingDeckSubmission
                } else {
                    VStack(spacing: 6) {
                        topBar(state: state)
                        opponentZone(state: state)
                        Divider().background(Color.white.opacity(0.15))
                        playerZone(state: state)
                        handSection(state: state)
                        footerBar(state: state)
                    }
                    .padding(8)
                    .onAppear { syncTrackedValues(state: state, initial: true) }
                    .onChange(of: state.playerA.player.hp) { syncTrackedValues(state: state) }
                    .onChange(of: state.playerB.player.hp) { syncTrackedValues(state: state) }
                    .onChange(of: state.playerA.player.moral) { syncTrackedValues(state: state) }
                    .onChange(of: state.playerB.player.moral) { syncTrackedValues(state: state) }
                    .onChange(of: state.playerA.player.block) { syncTrackedValues(state: state) }
                    .onChange(of: state.playerB.player.block) { syncTrackedValues(state: state) }
                    .onChange(of: store.match.isMyTurn) { _, newVal in
                        triggerTurnBannerIfNeeded(isMyTurn: newVal, state: state)
                    }
                    .onChange(of: state.previousTurnEvents.count) { _, newCount in
                        triggerRecapIfNeeded(state: state, newCount: newCount)
                    }
                }
            } else {
                matchmakingWaiting
            }

            Color(damageFlashColor)
                .opacity(damageFlashOpacity)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            if showLog, let state = store.duelState {
                logOverlay(state: state)
            }

            if showRecap, let state = store.duelState, !state.previousTurnEvents.isEmpty {
                recapOverlay(state: state)
            }

            if showTurnBanner {
                turnBanner
            }

            if store.isSaving {
                Color.black.opacity(0.55).ignoresSafeArea()
                ProgressView().scaleEffect(1.5).tint(.white)
            }

            if let state = store.duelState, state.isDuelOver {
                endgameOverlay(state: state)
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "duel.combat.forfeit_title",
            isPresented: $showForfeitConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "duel.combat.forfeit_confirm"), role: .destructive) {
                store.forfeit { result in
                    if case .failure(let e) = result { actionError = e.localizedDescription }
                }
            }
            Button(String(localized: "duel.combat.cancel"), role: .cancel) {}
        } message: {
            Text("duel.combat.forfeit_message")
        }
        .alert(
            String(localized: "duel.combat.invalid_action"),
            isPresented: .constant(actionError != nil),
            presenting: actionError
        ) { _ in
            Button(String(localized: "duel.combat.ok")) { actionError = nil }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Tracked value sync

    private func syncTrackedValues(state: DuelState, initial: Bool = false) {
        let myID = GameCenterManager.shared.myGamePlayerID ?? ""
        let me = state.playerA.playerID == myID ? state.playerA : state.playerB
        let opp = state.playerA.playerID == myID ? state.playerB : state.playerA

        let myHP = me.player.hp
        let oppHP = opp.player.hp
        let myMoral = me.player.moral
        let oppMoral = opp.player.moral
        let myBlock = me.player.block
        let oppBlock = opp.player.block

        if initial {
            lastMyHP = myHP; lastOppHP = oppHP
            lastMyMoral = myMoral; lastOppMoral = oppMoral
            lastMyBlock = myBlock; lastOppBlock = oppBlock
            return
        }

        if lastMyHP >= 0, myHP != lastMyHP {
            let delta = myHP - lastMyHP
            myHPFloatingValue = delta
            if delta < 0 { triggerDamageFlash(color: .red) }
        }
        lastMyHP = myHP

        if lastOppHP >= 0, oppHP != lastOppHP {
            oppHPFloatingValue = oppHP - lastOppHP
        }
        lastOppHP = oppHP

        if lastMyMoral >= 0, myMoral != lastMyMoral {
            let delta = myMoral - lastMyMoral
            myMoralFloatingValue = delta
            if delta < 0 { triggerDamageFlash(color: SalvageColor.moralPurple) }
        }
        lastMyMoral = myMoral

        if lastOppMoral >= 0, oppMoral != lastOppMoral {
            oppMoralFloatingValue = oppMoral - lastOppMoral
        }
        lastOppMoral = oppMoral

        if lastMyBlock >= 0, myBlock != lastMyBlock {
            myBlockFloatingValue = myBlock - lastMyBlock
        }
        lastMyBlock = myBlock

        if lastOppBlock >= 0, oppBlock != lastOppBlock {
            oppBlockFloatingValue = oppBlock - lastOppBlock
        }
        lastOppBlock = oppBlock
    }

    private func triggerDamageFlash(color: Color) {
        damageFlashColor = color
        withAnimation(.easeIn(duration: 0.08)) {
            damageFlashOpacity = 0.35
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.35)) {
                damageFlashOpacity = 0
            }
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Turn banner

    private func triggerTurnBannerIfNeeded(isMyTurn: Bool, state: DuelState) {
        guard !state.isDuelOver else { return }
        if lastIsMyTurn == isMyTurn { return }
        lastIsMyTurn = isMyTurn

        turnBannerKey = isMyTurn
            ? LocalizedStringKey("duel.combat.my_turn")
            : LocalizedStringKey("duel.combat.opponent_turn")

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            showTurnBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.35)) {
                showTurnBanner = false
            }
        }

        if isMyTurn {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private var turnBanner: some View {
        VStack {
            Spacer()
            Text(turnBannerKey)
                .font(SalvageFont.titleXL(30))
                .foregroundStyle(SalvageColor.boneWhite)
                .tracking(8)
                .shadow(color: .black.opacity(0.9), radius: 6)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.black.opacity(0.0),
                                     Color.black.opacity(0.75),
                                     Color.black.opacity(0.0)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Recap overlay

    private func triggerRecapIfNeeded(state: DuelState, newCount: Int) {
        guard newCount > 0, newCount != lastPreviousTurnEventsCount else {
            lastPreviousTurnEventsCount = newCount
            return
        }
        lastPreviousTurnEventsCount = newCount

        guard store.match.isMyTurn, !state.isDuelOver else { return }

        let myID = GameCenterManager.shared.myGamePlayerID ?? ""
        let hasOpponentAction = state.previousTurnEvents.contains {
            if case .cardPlayed(let pid, _, _) = $0 { return pid != myID }
            return false
        }
        guard hasOpponentAction else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showRecap = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showRecap = false
            }
        }
    }

    private func recapOverlay(state: DuelState) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(SalvageColor.energyOrange)
                    Text("duel.recap.title")
                        .font(SalvageFont.label(9))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .tracking(3)
                    Spacer()
                    Button {
                        withAnimation { showRecap = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                Divider().background(Color.white.opacity(0.2))
                ForEach(recapLines(state: state), id: \.self) { line in
                    Text("· \(line)")
                        .font(SalvageFont.body(11))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: 400)
            .background(Color.black.opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(SalvageColor.energyOrange.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.6), radius: 10)
            .padding(.bottom, 220)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .allowsHitTesting(true)
    }

    private func recapLines(state: DuelState) -> [String] {
        state.previousTurnEvents.compactMap { event -> String? in
            switch event {
            case .cardPlayed, .damageDealt, .moralChanged, .statusApplied,
                 .blockGained, .fatigueDamage, .turnSkipped:
                return eventLabel(event)
            default:
                return nil  // filtra turnEnded/cardDiscarded/cardsDrawn (ruído no recap)
            }
        }
    }

    // MARK: - Top bar

    private func topBar(state: DuelState) -> some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text("duel.combat.turn_label \(state.turn)")
                    .font(SalvageFont.label(9))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(3)
                Text(turnLabelKey(state: state))
                    .font(SalvageFont.header(12))
                    .foregroundStyle(store.match.isMyTurn
                                     ? SalvageColor.energyOrange
                                     : SalvageColor.boneWhite.opacity(0.7))
                    .tracking(2)
            }

            Spacer()

            if let state = store.duelState, !state.previousTurnEvents.isEmpty {
                Button {
                    withAnimation { showRecap.toggle() }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body)
                        .foregroundStyle(showRecap
                                         ? SalvageColor.energyOrange
                                         : .white.opacity(0.75))
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation { showLog.toggle() }
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                showForfeitConfirm = true
            } label: {
                Image(systemName: "flag.slash")
                    .font(.body)
                    .foregroundStyle(.orange.opacity(0.8))
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Opponent zone

    private func opponentZone(state: DuelState) -> some View {
        let opp = state.playerA.playerID == GameCenterManager.shared.myGamePlayerID
            ? state.playerB : state.playerA
        let name = store.match.opponent?.player?.displayName
            ?? String(localized: "duel.player.opponent_default_name")

        // Fase 10: tier + rating do oponente via metadata (se disponível)
        let oppTierInfo: (tier: RatingTier, rating: Int)? = {
            guard let meta = state.matchMetadata,
                  let myID = GameCenterManager.shared.myGamePlayerID,
                  let rating = meta.opponentRating(for: myID) else { return nil }
            return (RatingTier.tier(for: rating), rating)
        }()

        return HStack(alignment: .top, spacing: 16) {
            Image("avatar_placeholder")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(SalvageColor.bloodAccent.opacity(0.5), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(name.uppercased())
                        .font(SalvageFont.header(14))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .tracking(2)
                        .lineLimit(1)

                    // Fase 10: tier badge do oponente
                    if let info = oppTierInfo {
                        HStack(spacing: 3) {
                            Image(info.tier.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                            Text(info.tier.displayNameKey)
                                .font(SalvageFont.label(8))
                                .tracking(1)
                            Text("· \(info.rating)")
                                .font(SalvageFont.number(9))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(info.tier.accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(info.tier.accentColor.opacity(0.18))
                        .clipShape(Capsule())
                    }

                    if opp.player.statusEffects.count > 0 {
                        statusPills(effects: opp.player.statusEffects)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    animatedResourceBar(labelKey: "duel.combat.stat.hp",
                                        value: opp.player.hp, max: opp.player.maxHP,
                                        color: .red, floatValue: oppHPFloatingValue,
                                        floatColor: .red)
                    animatedResourceBar(labelKey: "duel.combat.stat.moral",
                                        value: opp.player.moral, max: opp.player.maxMoral,
                                        color: SalvageColor.moralPurple, floatValue: oppMoralFloatingValue,
                                        floatColor: SalvageColor.moralPurple)
                }

                HStack(spacing: 12) {
                    if opp.player.block > 0 {
                        miniStat(labelKey: "duel.combat.stat.block",
                                 value: "\(opp.player.block)", color: SalvageColor.blockBlue)
                            .changeEffect(
                                .rise(origin: .top) {
                                    Text("+\(oppBlockFloatingValue)")
                                        .font(SalvageFont.number(14))
                                        .foregroundStyle(SalvageColor.blockBlue.gradient)
                                        .shadow(color: .black, radius: 2)
                                },
                                value: oppBlockFloatingValue
                            )
                    }
                    miniStat(labelKey: "duel.combat.stat.hand", value: "\(opp.hand.count)", color: .white.opacity(0.65))
                    miniStat(labelKey: "duel.combat.stat.deck", value: "\(opp.drawPile.count)", color: .white.opacity(0.65))
                    miniStat(labelKey: "duel.combat.stat.discard_short", value: "\(opp.discardPile.count)", color: .white.opacity(0.65))
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(SalvageColor.bloodAccent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Player zone

    private func playerZone(state: DuelState) -> some View {
        let me = state.playerA.playerID == GameCenterManager.shared.myGamePlayerID
            ? state.playerA : state.playerB
        let name = GameCenterManager.shared.displayName

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(name.uppercased())
                        .font(SalvageFont.header(14))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .tracking(2)
                        .lineLimit(1)

                    if me.player.statusEffects.count > 0 {
                        statusPills(effects: me.player.statusEffects)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    animatedResourceBar(labelKey: "duel.combat.stat.hp",
                                        value: me.player.hp, max: me.player.maxHP,
                                        color: .red, floatValue: myHPFloatingValue,
                                        floatColor: .red)
                    animatedResourceBar(labelKey: "duel.combat.stat.moral",
                                        value: me.player.moral, max: me.player.maxMoral,
                                        color: SalvageColor.moralPurple, floatValue: myMoralFloatingValue,
                                        floatColor: SalvageColor.moralPurple)
                }

                HStack(spacing: 12) {
                    miniStat(labelKey: "duel.combat.stat.energy",
                             value: "\(me.player.energy)/\(me.player.maxEnergy)",
                             color: SalvageColor.energyOrange)
                    if me.player.block > 0 {
                        miniStat(labelKey: "duel.combat.stat.block",
                                 value: "\(me.player.block)", color: SalvageColor.blockBlue)
                            .changeEffect(
                                .rise(origin: .top) {
                                    Text("+\(myBlockFloatingValue)")
                                        .font(SalvageFont.number(14))
                                        .foregroundStyle(SalvageColor.blockBlue.gradient)
                                        .shadow(color: .black, radius: 2)
                                },
                                value: myBlockFloatingValue
                            )
                    }
                }
            }

            Spacer()

            endTurnButton(state: state)
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(SalvageColor.energyOrange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Resource bar / mini stat

    private func animatedResourceBar(labelKey: LocalizedStringKey, value: Int, max: Int,
                                     color: Color, floatValue: Int, floatColor: Color) -> some View {
        let ratio = max > 0 ? min(1.0, Double(value) / Double(max)) : 0
        return HStack(spacing: 6) {
            Text(labelKey)
                .font(SalvageFont.label(9))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(2)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * ratio)
                        .animation(.easeOut(duration: 0.4), value: value)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            }
            .frame(height: 14)

            Text("\(value)/\(max)")
                .font(SalvageFont.number(11))
                .foregroundStyle(SalvageColor.boneWhite)
                .frame(width: 56, alignment: .trailing)
                .changeEffect(
                    .rise(origin: .top) {
                        Text(floatValue >= 0 ? "+\(floatValue)" : "\(floatValue)")
                            .font(SalvageFont.number(18))
                            .foregroundStyle(floatColor.gradient)
                            .shadow(color: .black.opacity(0.9), radius: 3)
                    },
                    value: floatValue
                )
        }
    }

    private func miniStat(labelKey: LocalizedStringKey, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(labelKey)
                .font(SalvageFont.label(8))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)
            Text(value)
                .font(SalvageFont.number(11))
                .foregroundStyle(color)
        }
    }

    private func statusPills(effects: [StatusEffect: Int]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(effects), id: \.key) { key, value in
                HStack(spacing: 2) {
                    Text(statusIcon(key))
                    Text("\(value)")
                        .font(SalvageFont.number(10))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(statusColor(key))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - End turn button

    private func endTurnButton(state: DuelState) -> some View {
        let isMyTurn = store.match.isMyTurn && !state.isDuelOver
        return Button {
            selectedCardIndex = nil
            AudioManager.shared.playSFX(AudioTrack.sfxClick)
            store.endTurnHandingOver { result in
                if case .failure(let e) = result { actionError = e.localizedDescription }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                Text(isMyTurn
                     ? LocalizedStringKey("duel.combat.end_turn")
                     : LocalizedStringKey("duel.combat.wait"))
                    .font(SalvageFont.label(10))
                    .tracking(2)
            }
            .foregroundStyle(isMyTurn ? SalvageColor.boneWhite : .white.opacity(0.4))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMyTurn ? SalvageColor.energyOrange.opacity(0.75) : Color.black.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isMyTurn ? SalvageColor.energyOrange : Color.white.opacity(0.15),
                            lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!isMyTurn)
    }

    // MARK: - Hand

    private func handSection(state: DuelState) -> some View {
        let me = state.playerA.playerID == GameCenterManager.shared.myGamePlayerID
            ? state.playerA : state.playerB

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(me.hand.enumerated()), id: \.element.id) { index, card in
                    cardView(card: card, index: index, me: me, state: state)
                        .transition(.asymmetric(
                            insertion: .movingParts.pop(SalvageColor.energyOrange)
                                .combined(with: .move(edge: .bottom)),
                            removal: .movingParts.poof
                        ))
                }
                if me.hand.isEmpty {
                    Text("duel.combat.empty_hand")
                        .font(SalvageFont.body(11))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(height: 152)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: me.hand.map(\.id))
        }
        .frame(height: 170)
    }

    private func cardView(card: Card, index: Int, me: DuelPlayerState, state: DuelState) -> some View {
        let canAfford = me.player.energy >= card.cost
        let isMyTurn = store.match.isMyTurn && !state.isDuelOver
        let clickable = canAfford && isMyTurn
        let isSelected = selectedCardIndex == index
        let isTargetHint = selectedCardIndex != nil
            && card.targeting != .cardInHand
            && index != selectedCardIndex
            && requiresCardTarget(hand: me.hand, selectedIndex: selectedCardIndex ?? -1)

        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("\(card.cost)")
                    .font(SalvageFont.number(12))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(canAfford ? SalvageColor.energyOrange : Color.gray))
                Text(card.localizedName)
                    .font(SalvageFont.header(10))
                    .foregroundStyle(SalvageColor.boneWhite)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(5)
            .background(Color.black.opacity(0.85))

            if let art = card.artFilename {
                Image(art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 112, height: 80)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 112, height: 80)
            }

            VStack(alignment: .leading, spacing: 1) {
                ForEach(card.effects.indices, id: \.self) { i in
                    Text(effectText(card.effects[i]))
                        .font(SalvageFont.body(9))
                        .foregroundStyle(SalvageColor.boneWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(5)
            .background(Color(white: 0.13))
        }
        .frame(width: 112, height: 152)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(cardBorderColor(isSelected: isSelected,
                                        isTargetHint: isTargetHint,
                                        clickable: clickable),
                        lineWidth: (isSelected || isTargetHint) ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(clickable ? 1.0 : 0.5)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .shadow(color: isSelected ? SalvageColor.blockBlue.opacity(0.7) : .clear,
                radius: isSelected ? 10 : 0)
        .changeEffect(.shine, value: isSelected)
        .changeEffect(.shake(rate: .fast), value: cardShakeTriggers[card.id] ?? 0)
        .onTapGesture {
            handleCardTap(card: card, index: index, me: me, clickable: clickable)
        }
    }

    private func requiresCardTarget(hand: [Card], selectedIndex: Int) -> Bool {
        guard selectedIndex >= 0 && selectedIndex < hand.count else { return false }
        return hand[selectedIndex].targeting == .cardInHand
    }

    private func handleCardTap(card: Card, index: Int, me: DuelPlayerState, clickable: Bool) {
        guard clickable else {
            cardShakeTriggers[card.id, default: 0] += 1
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            return
        }

        if let selectedIdx = selectedCardIndex,
           selectedIdx != index,
           requiresCardTarget(hand: me.hand, selectedIndex: selectedIdx) {
            playCard(handIndex: selectedIdx, targetHandIndex: index)
            selectedCardIndex = nil
            return
        }

        AudioManager.shared.playSFX(AudioTrack.sfxCardPlay)

        switch card.targeting {
        case .none, .singleEnemy:
            playCard(handIndex: index, targetHandIndex: nil)
            selectedCardIndex = nil

        case .cardInHand:
            let others = me.hand.indices.filter { $0 != index }
            if others.isEmpty {
                cardShakeTriggers[card.id, default: 0] += 1
                actionError = String(localized: "duel.combat.need_hand_target")
                return
            }
            selectedCardIndex = (selectedCardIndex == index) ? nil : index
        }
    }

    private func playCard(handIndex: Int, targetHandIndex: Int?) {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()

        store.dispatch(.playCard(
            playerID: GameCenterManager.shared.myGamePlayerID ?? "",
            handIndex: handIndex,
            targetHandIndex: targetHandIndex
        )) { result in
            if case .failure(let e) = result {
                actionError = e.localizedDescription
            }
        }
    }

    // MARK: - Footer bar

    private func footerBar(state: DuelState) -> some View {
        let me = state.playerA.playerID == GameCenterManager.shared.myGamePlayerID
            ? state.playerA : state.playerB

        return HStack(spacing: 16) {
            pileCounter("duel.combat.pile.deck", me.drawPile.count)
            pileCounter("duel.combat.pile.discard", me.discardPile.count)
            pileCounter("duel.combat.pile.exile", me.exhaustPile.count)
            if me.fatigueCounter > 0 {
                pileCounter("duel.combat.pile.fatigue", me.fatigueCounter)
                    .foregroundStyle(.orange)
            }
            Spacer()

            if let idx = selectedCardIndex, idx < me.hand.count,
               requiresCardTarget(hand: me.hand, selectedIndex: idx) {
                Text("duel.combat.tap_other_target")
                    .font(SalvageFont.label(9))
                    .foregroundStyle(SalvageColor.blockBlue)
                    .tracking(3)

                Button {
                    selectedCardIndex = nil
                } label: {
                    Text("duel.combat.cancel_selection")
                        .font(SalvageFont.label(9))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func pileCounter(_ labelKey: LocalizedStringKey, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Text(labelKey)
                .font(SalvageFont.label(8))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(2)
            Text("\(value)")
                .font(SalvageFont.number(11))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Log overlay

    private func logOverlay(state: DuelState) -> some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("duel.combat.events_current_turn")
                            .font(SalvageFont.label(9))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(3)
                        Spacer()
                        Button {
                            withAnimation { showLog = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().background(Color.white.opacity(0.15))
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            if state.events.isEmpty {
                                Text("duel.combat.no_events_yet")
                                    .font(SalvageFont.body(11))
                                    .foregroundStyle(.white.opacity(0.5))
                            } else {
                                ForEach(state.events.indices, id: \.self) { i in
                                    Text("· \(eventLabel(state.events[i]))")
                                        .font(SalvageFont.body(11))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .frame(width: 320, height: 400)
                .background(Color.black.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.trailing, 16)
                .padding(.top, 60)
            }
            Spacer()
        }
    }

    // MARK: - Endgame overlay

    private func endgameOverlay(state: DuelState) -> some View {
        let iWon = state.winnerID == GameCenterManager.shared.myGamePlayerID
        let ratingResult = store.lastRatingResult
        return ZStack {
            // Fase 12: splash art de fundo — victory ou defeat conforme resultado.
            // Substitui o Color.black.opacity(0.85) puro do MVP; overlay preto
            // continua por cima com opacidade menor pra texto ler bem enquanto
            // a arte aparece por baixo.
            Image(iWon ? "bg_pvp_victory" : "bg_pvp_defeat")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(iWon
                     ? LocalizedStringKey("duel.combat.victory")
                     : LocalizedStringKey("duel.combat.defeat"))
                    .font(SalvageFont.titleXL(48))
                    .foregroundStyle(iWon ? SalvageColor.energyOrange : SalvageColor.bloodAccent)
                    .tracking(8)
                    .changeEffect(.shine.delay(0.3), value: state.isDuelOver)

                Rectangle()
                    .fill(iWon ? SalvageColor.energyOrange : SalvageColor.bloodAccent)
                    .frame(width: 80, height: 2)

                Text(iWon
                     ? LocalizedStringKey("duel.combat.victory_message")
                     : LocalizedStringKey("duel.combat.defeat_message"))
                    .font(SalvageFont.body(13))
                    .foregroundStyle(.white.opacity(0.75))

                // Fase 9: rating delta se disponível
                if let result = ratingResult {
                    ratingDeltaCard(result: result, iWon: iWon)
                        .padding(.top, 8)
                }

                Button {
                    onBack()
                } label: {
                    Text("duel.combat.back_to_duels_button")
                        .font(SalvageFont.label(11))
                        .tracking(3)
                        .foregroundStyle(SalvageColor.boneWhite)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(SalvageColor.boneWhite.opacity(0.4), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .onAppear {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(store.duelState?.winnerID == GameCenterManager.shared.myGamePlayerID
                                     ? .success : .error)
        }
    }

    /// Card compacto mostrando "1000 → 1032 (+32)" com animação de tier change
    /// se aplicável. Só renderizado se `store.lastRatingResult != nil` (Fase 9
    /// aplicou delta com sucesso).
    private func ratingDeltaCard(
        result: RatingStore.DuelResultApplication,
        iWon: Bool
    ) -> some View {
        let deltaColor: Color = result.delta >= 0
            ? SalvageColor.energyOrange
            : SalvageColor.bloodAccent
        let deltaSign = result.delta >= 0 ? "+" : ""
        return VStack(spacing: 8) {
            // Rating antes → depois
            HStack(spacing: 10) {
                Text("\(result.oldRating)")
                    .font(SalvageFont.number(20))
                    .foregroundStyle(.white.opacity(0.55))
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Text("\(result.newRating)")
                    .font(SalvageFont.number(24))
                    .foregroundStyle(SalvageColor.boneWhite)
                Text("(\(deltaSign)\(result.delta))")
                    .font(SalvageFont.number(16))
                    .foregroundStyle(deltaColor)
            }

            // Tier change (se houver)
            if result.tierChanged {
                HStack(spacing: 6) {
                    Image(systemName: result.promoted
                          ? "arrow.up.circle.fill"
                          : "arrow.down.circle.fill")
                        .foregroundStyle(result.promoted
                                         ? SalvageColor.energyOrange
                                         : SalvageColor.bloodAccent)
                    Text(result.promoted
                         ? LocalizedStringKey("duel.rank.promoted")
                         : LocalizedStringKey("duel.rank.demoted"))
                        .font(SalvageFont.label(9))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(result.newTier.displayNameKey)
                        .font(SalvageFont.header(11))
                        .tracking(2)
                        .foregroundStyle(result.newTier.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .changeEffect(.shine.delay(0.5), value: result.newTier)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(deltaColor.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Matchmaking waiting

    private var matchmakingWaiting: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.5).tint(.white)
            Text("duel.matchmaking.title")
                .font(SalvageFont.label(10))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(3)
            Text("duel.matchmaking.message")
                .font(SalvageFont.body(11))
                .foregroundStyle(.white.opacity(0.55))
            Button(action: onBack) {
                Text("duel.matchmaking.back")
                    .font(SalvageFont.label(10))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }

    // MARK: - Awaiting deck submission (Fase 8)

    private var awaitingDeckSubmission: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.badge.a.fill")
                .font(.system(size: 44))
                .foregroundStyle(SalvageColor.energyOrange.opacity(0.85))
            Text("duel.deck.awaiting_title")
                .font(SalvageFont.label(10))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(3)
            Text("duel.deck.awaiting_message")
                .font(SalvageFont.body(11))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onBack) {
                Text("duel.matchmaking.back")
                    .font(SalvageFont.label(10))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }

    // MARK: - Labels / helpers

    private func turnLabelKey(state: DuelState) -> LocalizedStringKey {
        if state.isDuelOver { return LocalizedStringKey("duel.combat.ended") }
        return store.match.isMyTurn
            ? LocalizedStringKey("duel.combat.my_turn")
            : LocalizedStringKey("duel.combat.opponent_turn")
    }

    private func cardBorderColor(isSelected: Bool, isTargetHint: Bool, clickable: Bool) -> Color {
        if isSelected { return SalvageColor.blockBlue }
        if isTargetHint { return SalvageColor.blockBlue.opacity(0.6) }
        return clickable ? Color.white.opacity(0.25) : Color.white.opacity(0.1)
    }

    // MARK: - Card effect text (mesmo do CombatView single-player — chaves já i18n)

    private func effectText(_ effect: CardEffect) -> String {
        switch effect {
        case .damage(let d):            return String(localized: "combat.damage_short \(d)")
        case .damageAll(let d):         return String(localized: "combat.damage_all_short \(d)")
        case .damageSelfMoral(let d):   return String(localized: "combat.damage_self_short \(d)")
        case .gainBlock(let b):         return String(localized: "combat.block_short \(b)")
        case .gainMoral(let m):         return String(localized: "combat.moral_short \(m)")
        case .applyStatus(let s, let n):    return "\(statusIcon(s)) \(n)"
        case .applyStatusAll(let s, let n): return "\(statusIcon(s)) \(n)"
        case .exhaustFromHand:          return String(localized: "combat.exhaust_short")
        case .exhaustChosenFromHand:    return String(localized: "combat.exhaust_chosen_short")
        case .draw(let n):              return String(localized: "combat.draw_short \(n)")
        case .skipNextTurn:             return String(localized: "combat.stun_short")
        case .revealAllIntents:         return String(localized: "combat.reveal_short")
        }
    }

    // MARK: - Status effect visuals

    private func statusIcon(_ s: StatusEffect) -> String {
        switch s {
        case .block: return "🛡"
        case .fear: return "👁"
        case .fatigue: return "💤"
        case .corruption: return "🕳"
        case .skipNextTurn: return "⏭"
        }
    }

    /// Nome localizado do status effect. Usado no recap ("Você recebeu 2 Medo").
    private func statusName(_ s: StatusEffect) -> String {
        switch s {
        case .block: return String(localized: "duel.status_effect.block")
        case .fear: return String(localized: "duel.status_effect.fear")
        case .fatigue: return String(localized: "duel.status_effect.fatigue")
        case .corruption: return String(localized: "duel.status_effect.corruption")
        case .skipNextTurn: return String(localized: "duel.status_effect.skip_next_turn")
        }
    }

    private func statusColor(_ s: StatusEffect) -> Color {
        switch s {
        case .block: return SalvageColor.blockBlue.opacity(0.7)
        case .fear: return SalvageColor.moralPurple.opacity(0.7)
        case .fatigue: return .gray.opacity(0.7)
        case .corruption: return SalvageColor.bloodAccent.opacity(0.7)
        case .skipNextTurn: return .orange.opacity(0.7)
        }
    }

    // MARK: - Event → localized label

    /// Traduz um DuelEvent em string localizada. Usa "Você" / "Adversário" pra
    /// deixar a leitura natural em vez dos IDs opacos do Game Center.
    private func eventLabel(_ event: DuelEvent) -> String {
        let myID = GameCenterManager.shared.myGamePlayerID ?? ""
        func who(_ id: String) -> String {
            id == myID
                ? String(localized: "duel.player.you")
                : String(localized: "duel.player.opponent")
        }

        switch event {
        case .duelStarted:
            return String(localized: "duel.event.duel_started")
        case .turnStarted(let pid, let t):
            return String(localized: "duel.event.turn_started \(t) \(who(pid))")
        case .cardPlayed(let pid, _, let name):
            return String(localized: "duel.event.card_played \(who(pid)) \(name)")
        case .damageDealt(let tid, let amt, let blk):
            var base = String(localized: "duel.event.damage_dealt \(who(tid)) \(amt)")
            if blk > 0 {
                base += String(localized: "duel.event.damage_blocked_part \(blk)")
            }
            return base
        case .moralChanged(let tid, let d):
            if d >= 0 {
                return String(localized: "duel.event.moral_gained \(who(tid)) \(d)")
            } else {
                return String(localized: "duel.event.moral_lost \(who(tid)) \(-d)")
            }
        case .hpChanged(let tid, let d):
            return String(localized: "duel.event.hp_change \(who(tid)) \(d)")
        case .blockGained(let pid, let amt):
            return String(localized: "duel.event.block_gained \(who(pid)) \(amt)")
        case .statusApplied(let tid, let s, let n):
            return String(localized: "duel.event.status_applied \(who(tid)) \(n) \(statusName(s))")
        case .cardsDrawn(let pid, let n):
            return String(localized: "duel.event.cards_drawn \(who(pid)) \(n)")
        case .cardDiscarded(let pid, _):
            return String(localized: "duel.event.card_discarded \(who(pid))")
        case .cardExhausted(let pid, _):
            return String(localized: "duel.event.card_exhausted \(who(pid))")
        case .deckShuffled(let pid):
            return String(localized: "duel.event.deck_shuffled \(who(pid))")
        case .fatigueDamage(let pid, let amt):
            return String(localized: "duel.event.fatigue_damage \(who(pid)) \(amt)")
        case .skipTurnApplied(let tid):
            return String(localized: "duel.event.skip_turn_applied \(who(tid))")
        case .turnSkipped(let pid):
            return String(localized: "duel.event.turn_skipped \(who(pid))")
        case .turnEnded(let pid):
            return String(localized: "duel.event.turn_ended \(who(pid))")
        case .duelWon(let wid):
            return String(localized: "duel.event.duel_won \(who(wid))")
        case .duelForfeit(let lid):
            return String(localized: "duel.event.duel_forfeit \(who(lid))")
        }
    }
}
