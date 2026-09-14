//
//  RatingStore.swift
//  Salvage Corps
//
//  Fase 9: rating persistido em UserDefaults + submit ao Game Center
//  leaderboard "duel_rating".
//

import Foundation
import Observation
import GameKit
import SwiftUI
import SalvageCore

// MARK: - Tier system

/// Tiers visuais baseados em rating. Puramente cosmético — matchmaking não usa
/// isso (Game Center auto-match ignora tier). Motivação: dar sensação de
/// progresso pro jogador sem impactar pool de matchmaking (que já é pequeno
/// num MVP indie).
enum RatingTier: Int, CaseIterable, Comparable {
    case recruta = 0        // 0-999
    case soldado = 1000     // 1000-1199
    case sargento = 1200    // 1200-1399
    case tenente = 1400     // 1400-1599
    case capitao = 1600     // 1600-1799
    case oficial = 1800     // 1800+

    static func < (lhs: RatingTier, rhs: RatingTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Tier correspondente a um rating (encontra o maior tier cujo `minRating <= rating`).
    static func tier(for rating: Int) -> RatingTier {
        RatingTier.allCases.reversed().first { rating >= $0.rawValue } ?? .recruta
    }

    var minRating: Int { rawValue }

    /// Rating mínimo do PRÓXIMO tier. Nil se já é o topo.
    var nextTierMinRating: Int? {
        guard let idx = RatingTier.allCases.firstIndex(of: self),
              idx + 1 < RatingTier.allCases.count else { return nil }
        return RatingTier.allCases[idx + 1].minRating
    }

    /// Chave i18n do nome do tier ("Recruta", "Soldado", etc).
    var displayNameKey: LocalizedStringKey {
        switch self {
        case .recruta:  return "duel.rank.recruta"
        case .soldado:  return "duel.rank.soldado"
        case .sargento: return "duel.rank.sargento"
        case .tenente:  return "duel.rank.tenente"
        case .capitao:  return "duel.rank.capitao"
        case .oficial:  return "duel.rank.oficial"
        }
    }

    /// Cor de destaque do tier — usada em badges, endgame overlay.
    var accentColor: Color {
        switch self {
        case .recruta:  return .gray
        case .soldado:  return .white.opacity(0.7)
        case .sargento: return SalvageColor.blockBlue
        case .tenente:  return SalvageColor.energyOrange
        case .capitao:  return SalvageColor.moralPurple
        case .oficial:  return SalvageColor.bloodAccent
        }
    }

    /// SF Symbol pro badge do tier — usa insignias militares aproximadas.
    var iconName: String {
        switch self {
        case .recruta:  return "person.fill"
        case .soldado:  return "shield.fill"
        case .sargento: return "chevron.up.2"
        case .tenente:  return "chevron.up.3"
        case .capitao:  return "star.fill"
        case .oficial:  return "star.circle.fill"
        }
    }

    /// **Fase 12**: nome do asset PNG custom em Assets.xcassets.
    /// Substitui o SF Symbol de `iconName` — arte dedicada WW1 grimdark
    /// gerada especificamente pro modo PVP (não usa SF Symbol genérico).
    /// `iconName` fica mantido como fallback caso o asset esteja ausente.
    var assetName: String {
        switch self {
        case .recruta:  return "tier_recruta"
        case .soldado:  return "tier_soldado"
        case .sargento: return "tier_sargento"
        case .tenente:  return "tier_tenente"
        case .capitao:  return "tier_capitao"
        case .oficial:  return "tier_oficial"
        }
    }
}


// MARK: - RatingStore

@Observable
@MainActor
final class RatingStore {

    static let shared = RatingStore()

    /// Rating inicial de um novo jogador. Meio da escala pra dar espaço
    /// de subir/descer sem chegar em extremos rapidamente.
    static let startingRating: Int = 1000

    /// ID do leaderboard configurado no App Store Connect.
    /// **AÇÃO NECESSÁRIA**: criar esse leaderboard com Format=Integer,
    /// Sort=High to Low, Score submission=Best.
    static let leaderboardID: String = "duel_rating"

    /// Rating atual do usuário. Setter persiste em UserDefaults + submete
    /// ao leaderboard automaticamente (quando muda).
    var currentRating: Int {
        didSet {
            guard currentRating != oldValue else { return }
            persist()
            submitToLeaderboard()
        }
    }

    /// **Fase 10**: total de vitórias ranked contabilizadas.
    /// Incrementado (junto com losses) em `applyDuelResult`. Idempotência
    /// mantida via `processedMatchIDs` — cada match conta 1 vez só.
    private(set) var wins: Int {
        didSet {
            guard wins != oldValue else { return }
            UserDefaults.standard.set(wins, forKey: Self.winsKey)
        }
    }

    /// **Fase 10**: total de derrotas ranked contabilizadas.
    private(set) var losses: Int {
        didSet {
            guard losses != oldValue else { return }
            UserDefaults.standard.set(losses, forKey: Self.lossesKey)
        }
    }

    /// Total de matches ranked terminados. Base pro cálculo de winrate.
    var totalMatches: Int { wins + losses }

    /// Winrate como fração (0.0 a 1.0). Zero se totalMatches é zero.
    var winrate: Double {
        guard totalMatches > 0 else { return 0 }
        return Double(wins) / Double(totalMatches)
    }

    /// **Fase 11**: streak atual de vitórias consecutivas. Incrementa em vitória,
    /// **zera em derrota**. Usado pra achievements de streak.
    private(set) var currentStreak: Int {
        didSet {
            guard currentStreak != oldValue else { return }
            UserDefaults.standard.set(currentStreak, forKey: Self.currentStreakKey)
            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }
        }
    }

    /// **Fase 11**: maior streak já alcançado. Só cresce, nunca reduz.
    /// Motivador de longo prazo mesmo se player está numa má fase.
    private(set) var bestStreak: Int {
        didSet {
            guard bestStreak != oldValue else { return }
            UserDefaults.standard.set(bestStreak, forKey: Self.bestStreakKey)
        }
    }

    // MARK: Storage

    private static let ratingKey = "sc.duel.rating.v1"
    private static let processedMatchesKey = "sc.duel.processedMatches.v1"
    private static let winsKey = "sc.duel.wins.v1"
    private static let lossesKey = "sc.duel.losses.v1"
    private static let currentStreakKey = "sc.duel.currentStreak.v1"
    private static let bestStreakKey = "sc.duel.bestStreak.v1"

    private init() {
        // Precisa inicializar TODAS as stored properties antes de qualquer uso
        // de `self` (regra do Swift). Usa vars locais e só toca UserDefaults
        // depois que tudo tá setado.
        let existingRating = UserDefaults.standard.object(forKey: Self.ratingKey) as? Int
        let rating = existingRating ?? Self.startingRating

        // 1) Todas as stored properties primeiro
        self.currentRating = rating
        self.wins = UserDefaults.standard.integer(forKey: Self.winsKey)
        self.losses = UserDefaults.standard.integer(forKey: Self.lossesKey)
        self.currentStreak = UserDefaults.standard.integer(forKey: Self.currentStreakKey)
        self.bestStreak = UserDefaults.standard.integer(forKey: Self.bestStreakKey)

        // 2) Só agora pode usar self / persistir default
        if existingRating == nil {
            UserDefaults.standard.set(rating, forKey: Self.ratingKey)
        }
    }

    private func persist() {
        UserDefaults.standard.set(currentRating, forKey: Self.ratingKey)
    }

    // MARK: Idempotência (matches processados)

    /// IDs de matches cujo delta já foi aplicado. Previne double-apply se
    /// UI reabrir a mesma match terminada 2x.
    private var processedMatchIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: Self.processedMatchesKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.processedMatchesKey)
        }
    }

    func hasProcessed(matchID: String) -> Bool {
        processedMatchIDs.contains(matchID)
    }

    // MARK: Apply duel result

    struct DuelResultApplication {
        let oldRating: Int
        let newRating: Int
        let delta: Int
        let oldTier: RatingTier
        let newTier: RatingTier
        var tierChanged: Bool { oldTier != newTier }
        var promoted: Bool { newTier > oldTier }
        var demoted: Bool { newTier < oldTier }
    }

    /// Aplica delta ELO ao rating atual. Idempotente por `matchID` — se já
    /// processado, retorna nil sem alterar nada.
    ///
    /// - Parameters:
    ///   - matchID: `GKTurnBasedMatch.matchID` — chave de idempotência
    ///   - myRatingAtStart: rating do player quando o match começou
    ///     (do `matchMetadata`, congelado)
    ///   - opponentRatingAtStart: idem pro oponente
    ///   - iWon: true se ganhei o duelo
    /// - Returns: descrição do que aconteceu, ou nil se match já processado
    ///   ou se metadata inválida (rating congelado <= 0)
    @discardableResult
    func applyDuelResult(
        matchID: String,
        myRatingAtStart: Int,
        opponentRatingAtStart: Int,
        iWon: Bool
    ) -> DuelResultApplication? {
        // Idempotência
        guard !processedMatchIDs.contains(matchID) else {
            print("[RatingStore] Match \(matchID) já processado — pulando")
            return nil
        }
        // Validação básica — se metadata veio corrompida (0 significa "não setado
        // no Fase 8 legacy"), não processa. Melhor sacrificar o rating desse
        // match do que aplicar delta bugado.
        guard myRatingAtStart > 0, opponentRatingAtStart > 0 else {
            print("[RatingStore] Rating congelado inválido (my=\(myRatingAtStart), opp=\(opponentRatingAtStart)) — pulando")
            return nil
        }

        let result: Double = iWon ? 1.0 : 0.0
        let delta = RatingCalculator.delta(
            myRating: myRatingAtStart,
            opponentRating: opponentRatingAtStart,
            result: result
        )

        let oldRating = currentRating
        let oldTier = RatingTier.tier(for: oldRating)

        // Apply DELTA em cima do current (não replace pelo newRating) —
        // handles corretamente múltiplos matches concorrentes.
        // Piso em 0 pra não permitir rating negativo.
        currentRating = max(0, currentRating + delta)

        // Fase 10: incrementa W/L junto (mesma idempotência via processedMatchIDs)
        // Fase 11: streak — incrementa em vitória, zera em derrota
        if iWon {
            wins += 1
            currentStreak += 1
        } else {
            losses += 1
            currentStreak = 0
        }

        // Marca match processado
        var ids = processedMatchIDs
        ids.insert(matchID)
        processedMatchIDs = ids

        let newTier = RatingTier.tier(for: currentRating)

        print("[RatingStore] Match \(matchID): \(oldRating) → \(currentRating) (delta=\(delta), iWon=\(iWon))")

        return DuelResultApplication(
            oldRating: oldRating,
            newRating: currentRating,
            delta: currentRating - oldRating,
            oldTier: oldTier,
            newTier: newTier
        )
    }

    // MARK: Game Center leaderboard

    /// Submete o rating atual pro leaderboard `duel_rating`. Silent-fail —
    /// se falhar (offline, leaderboard não configurado), só loga.
    /// Chamado automaticamente no didSet do currentRating.
    private func submitToLeaderboard() {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("[RatingStore] Não autenticado, pulando submit ao leaderboard")
            return
        }
        GKLeaderboard.submitScore(
            currentRating,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.leaderboardID]
        ) { error in
            if let error = error {
                print("[RatingStore] Falha ao submeter score: \(error.localizedDescription)")
            } else {
                print("[RatingStore] Score \(self.currentRating) submetido ao leaderboard")
            }
        }
    }

    /// Força re-submit (útil quando o user acaba de autenticar após já ter
    /// jogado offline).
    func forceResubmit() {
        submitToLeaderboard()
    }

    // MARK: Reset (útil pra desenvolvimento; UI não expõe)

    /// Zera rating e limpa histórico. Só chame em contexto controlado —
    /// não tem confirmação, não tem undo.
    func devReset() {
        currentRating = Self.startingRating
        processedMatchIDs = []
        wins = 0
        losses = 0
        currentStreak = 0
        bestStreak = 0
        print("[RatingStore] DEV RESET aplicado")
    }
}
