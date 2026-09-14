import Foundation

// MARK: - Achievement definitions

/// Definição dos achievements do modo Duelos. Cada case corresponde a um
/// achievement configurado no App Store Connect com o **exato** mesmo ID
/// (`rawValue`). Ausência de config no ASC = report silenciosamente ignorado
/// pelo Game Center (não crasha).
public enum Achievement: String, CaseIterable, Codable {

    // Tier progression (visible)
    case tierSargento = "sc.tier.sargento"
    case tierTenente  = "sc.tier.tenente"
    case tierCapitao  = "sc.tier.capitao"
    case tierOficial  = "sc.tier.oficial"

    // Win milestones (progress-based, visible)
    case wins1   = "sc.wins.1"
    case wins10  = "sc.wins.10"
    case wins50  = "sc.wins.50"
    case wins100 = "sc.wins.100"

    // Match participation (progress-based, visible)
    case matches10 = "sc.matches.10"
    case matches50 = "sc.matches.50"

    // Streaks (all-or-nothing, visible)
    case streak3 = "sc.streak.3"
    case streak5 = "sc.streak.5"

    // Feats (hidden until achieved)
    case perfectDuel = "sc.perfect_duel"
    case underdog    = "sc.underdog"

    /// ID a passar pro `GKAchievement(identifier:)` — igual ao rawValue.
    public var identifier: String { rawValue }

    /// True se o achievement suporta progress incremental (ex: 5/10).
    /// Game Center exibe barra de progresso pra esses.
    public var isProgressBased: Bool {
        targetValue != nil
    }

    /// Target numérico pra achievements com progresso. Nil pra all-or-nothing.
    public var targetValue: Int? {
        switch self {
        case .wins10:    return 10
        case .wins50:    return 50
        case .wins100:   return 100
        case .matches10: return 10
        case .matches50: return 50
        default:         return nil
        }
    }

    /// Chave i18n pro título — usada em achievement definitions no ASC E
    /// pra referência interna. UI real vem do Game Center.
    public var titleKey: String {
        "achievement.\(rawValue).title"
    }

    /// Chave i18n pra descrição pré-conquista ("Ganhe 10 duelos").
    public var descriptionLockedKey: String {
        "achievement.\(rawValue).desc_locked"
    }

    /// Chave i18n pra descrição pós-conquista ("Ganhou 10 duelos").
    public var descriptionUnlockedKey: String {
        "achievement.\(rawValue).desc_unlocked"
    }
}


// MARK: - Evaluator input

/// Snapshot de tudo que o evaluator precisa pra decidir quais achievements
/// disparar após um duelo terminar. Populado pelo caller (DuelMatchStore)
/// combinando dados de RatingStore, DuelState e matchMetadata.
public struct DuelOutcomeSnapshot: Equatable {
    /// True se o LOCAL player venceu.
    public let iWon: Bool

    /// Rating do local player DEPOIS de aplicar delta.
    public let myRatingAfter: Int

    /// Rating do oponente no início do match (congelado no metadata).
    /// Zero se metadata inválido — evaluator trata como "sem info".
    public let opponentRatingAtStart: Int

    /// Rating do local player NO INÍCIO do match (congelado).
    public let myRatingAtStart: Int

    /// True se o local player não tomou nenhum dano — HP final == HP máximo.
    /// Usado pro `perfectDuel`. Fatigue conta como dano — se HP < maxHP por
    /// qualquer motivo, não é perfeito.
    public let iTookNoDamage: Bool

    /// Total de vitórias do local player DEPOIS de aplicar delta.
    public let totalWinsAfter: Int

    /// Total de matches ranked terminados DEPOIS de aplicar delta.
    public let totalMatchesAfter: Int

    /// Streak atual DEPOIS de aplicar delta. Se `iWon`, esse valor foi
    /// incrementado; se perdeu, foi zerado.
    public let currentStreakAfter: Int

    public init(
        iWon: Bool,
        myRatingAfter: Int,
        opponentRatingAtStart: Int,
        myRatingAtStart: Int,
        iTookNoDamage: Bool,
        totalWinsAfter: Int,
        totalMatchesAfter: Int,
        currentStreakAfter: Int
    ) {
        self.iWon = iWon
        self.myRatingAfter = myRatingAfter
        self.opponentRatingAtStart = opponentRatingAtStart
        self.myRatingAtStart = myRatingAtStart
        self.iTookNoDamage = iTookNoDamage
        self.totalWinsAfter = totalWinsAfter
        self.totalMatchesAfter = totalMatchesAfter
        self.currentStreakAfter = currentStreakAfter
    }
}


// MARK: - Evaluator

/// Puro — mesmo input sempre gera mesmo output. Testado em unit.
/// Retorna tuplas `(achievement, percentComplete)` pra reportar via GKAchievement.
///
/// **Regras de percent**:
/// - Progress-based: `min(1.0, current/target)` — sempre reporta, Game Center
///   preserva o maior valor (nunca "regride" um achievement)
/// - All-or-nothing: reporta 1.0 (100%) só quando conquistado; senão não retorna
///
/// **Não checa idempotência** — Game Center faz isso do lado dele. Reportar
/// achievement já conquistado é no-op pro user.
public struct AchievementEvaluator {

    public static func evaluate(_ input: DuelOutcomeSnapshot) -> [(Achievement, Double)] {
        var results: [(Achievement, Double)] = []

        // Tier achievements (só se ganhou/subiu de fato — checa rating atual)
        // Reportar sempre mesmo se já conquistou (Game Center dedupe).
        if input.myRatingAfter >= 1200 { results.append((.tierSargento, 1.0)) }
        if input.myRatingAfter >= 1400 { results.append((.tierTenente, 1.0)) }
        if input.myRatingAfter >= 1600 { results.append((.tierCapitao, 1.0)) }
        if input.myRatingAfter >= 1800 { results.append((.tierOficial, 1.0)) }

        // Match participation — progress-based (reporta sempre, GC preserva máximo)
        for ach in [Achievement.matches10, .matches50] {
            if let target = ach.targetValue {
                let pct = min(1.0, Double(input.totalMatchesAfter) / Double(target))
                results.append((ach, pct))
            }
        }

        // Win-only achievements — só reportar se realmente venceu esse match
        // (evita duplicar report em derrota, que não muda o count de wins).
        if input.iWon {
            // Primeira vitória — all-or-nothing
            if input.totalWinsAfter >= 1 {
                results.append((.wins1, 1.0))
            }

            // Wins progress-based
            for ach in [Achievement.wins10, .wins50, .wins100] {
                if let target = ach.targetValue {
                    let pct = min(1.0, Double(input.totalWinsAfter) / Double(target))
                    results.append((ach, pct))
                }
            }

            // Streaks — só quando bate o threshold (all-or-nothing por conveniência)
            if input.currentStreakAfter >= 3 { results.append((.streak3, 1.0)) }
            if input.currentStreakAfter >= 5 { results.append((.streak5, 1.0)) }

            // Perfect duel — hidden
            if input.iTookNoDamage {
                results.append((.perfectDuel, 1.0))
            }

            // Underdog — venceu contra oponente 200+ pontos acima do rating inicial
            if input.opponentRatingAtStart > 0,
               input.opponentRatingAtStart >= input.myRatingAtStart + 200 {
                results.append((.underdog, 1.0))
            }
        }

        return results
    }
}
