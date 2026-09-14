import Foundation

/// Escolha terminal ao fim de um ato. Persiste no ProgressStore
/// entre runs pra influenciar endings do Ato 3.
///
/// Cada ato tem 3 opções que empurram o player em direção a
/// um dos 5 endings possíveis:
/// - **O Cúmplice**: aliado leal do Corps (report, seguir ordens)
/// - **O Contentor**: proteger a unidade (silenciar, absorver o peso)
/// - **O Testemunha**: guardar a verdade (duvidar, documentar em segredo)
/// - **O Fugitivo**: (destravado por combinação específica de escolhas)
/// - **O Espelho**: (secreto — meta-layer do Ato 3)
public enum TerminalChoice: String, Codable, CaseIterable, Sendable, Identifiable {

    // Ato 1 choices
    case reportContact       // → path Cúmplice
    case silenceIncident     // → path Contentor
    case doubtEverything     // → path Testemunha

    // Ato 2 choices
    case recordAtoll         // → path Cúmplice (grava tudo no Corps)
    case buryWithUnit        // → path Contentor (enterra o Apóstolo, silencia)
    case keepSymbol          // → path Testemunha (leva evidência secreta)

    // Ato 3 choices — decisão final sobre o arquivo do Corps
    case salvageArchive      // → path Cúmplice (preserva pro Corps)
    case burnEverything      // → path Contentor (destrói tudo)
    case walkAway            // → path Testemunha / Fugitivo (sai sem tocar)

    public var id: String { rawValue }

    /// Ato ao qual esta escolha pertence.
    public var act: Int {
        switch self {
        case .reportContact, .silenceIncident, .doubtEverything: return 1
        case .recordAtoll, .buryWithUnit, .keepSymbol: return 2
        case .salvageArchive, .burnEverything, .walkAway: return 3
        }
    }

    /// Path narrativo influenciado por esta escolha.
    public var endingInfluence: EndingPath {
        switch self {
        case .reportContact, .recordAtoll, .salvageArchive:    return .complice
        case .silenceIncident, .buryWithUnit, .burnEverything: return .contentor
        case .doubtEverything, .keepSymbol, .walkAway:         return .testemunha
        }
    }
}

/// Um dos 5 endings possíveis do jogo. Cada TerminalChoice empurra
/// pra um. O ending final é calculado pela combinação de todas as
/// escolhas ao longo dos 3 atos + condições ocultas.
public enum EndingPath: String, Codable, Sendable, CaseIterable {
    case complice
    case contentor
    case testemunha
    case fugitivo
    case espelho  // secret

    public var displayName: String {
        switch self {
        case .complice:   return "O Cúmplice"
        case .contentor:  return "O Contentor"
        case .testemunha: return "O Testemunha"
        case .fugitivo:   return "O Fugitivo"
        case .espelho:    return "O Espelho"
        }
    }
}

// ============================================================================
// MARK: - ActConsequences
// ============================================================================

/// Consequências acumuladas das escolhas terminais.
///
/// Persistido em `ProgressStore` — SOBREVIVE entre runs (mesmo se player
/// abandonar/perder). Isso é essencial pro Ato 3 conseguir referenciar
/// escolhas específicas feitas em runs anteriores.
public struct ActConsequences: Codable, Equatable, Sendable {

    /// Escolha do Ato 1. Nil se ainda não completou.
    public var act1: TerminalChoice?

    /// Escolha do Ato 2. Nil se ainda não completou.
    public var act2: TerminalChoice?

    /// Escolha do Ato 3 (afeta ending final direto).
    public var act3: TerminalChoice?

    public init(
        act1: TerminalChoice? = nil,
        act2: TerminalChoice? = nil,
        act3: TerminalChoice? = nil
    ) {
        self.act1 = act1
        self.act2 = act2
        self.act3 = act3
    }

    // MARK: - Queries

    /// Retorna a escolha do ato dado. Nil se ato não completado.
    public func choice(forAct act: Int) -> TerminalChoice? {
        switch act {
        case 1: return act1
        case 2: return act2
        case 3: return act3
        default: return nil
        }
    }

    /// Retorna todas as escolhas feitas (não-nil), em ordem cronológica.
    public var allChoices: [TerminalChoice] {
        [act1, act2, act3].compactMap { $0 }
    }

    /// Path predominante nas escolhas feitas até agora. Usado como preview
    /// do ending mais provável se player continuar na trajetória atual.
    /// Nil se sem escolhas ou empate.
    public var currentEndingPrediction: EndingPath? {
        let counts = allChoices.reduce(into: [EndingPath: Int]()) { acc, choice in
            acc[choice.endingInfluence, default: 0] += 1
        }
        guard let max = counts.max(by: { $0.value < $1.value }) else { return nil }
        // Empate → nil (indefinido)
        let tied = counts.filter { $0.value == max.value }
        return tied.count == 1 ? max.key : nil
    }
}
