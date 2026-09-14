import Foundation

/// Um inimigo em combate.
///
/// Value type. Suporta bosses multi-fase opcionalmente — se `phasePatterns` for
/// nil (default), usa `intentPattern` fixo como enemies normais. Se preenchido,
/// muda de padrão dinamicamente conforme HP cai abaixo dos `phaseThresholds`.
public struct Enemy: Identifiable, Equatable, Hashable, Codable {

    public let id: UUID
    public let name: String
    public let maxHP: Int
    public var hp: Int

    /// Padrão único de intents pra enemies normais. Pra bosses, é um fallback
    /// (equivalente ao `phasePatterns[0]`) — se você definir `phasePatterns`,
    /// esse fica ignorado.
    public let intentPattern: IntentPattern

    public var turnsCompleted: Int
    public var statusEffects: [StatusEffect: Int]
    public var skipNextTurn: Bool
    public let flavor: String
    public let artFilename: String?

    // MARK: - Fog of War (Ato 2+)

    /// Se true, `currentIntent` é ocultado da UI por default.
    /// Player precisa jogar carta que revele (ex: "Escuta Atenta").
    /// Enemies do Ato 1 sempre têm intent visível (default false).
    public let intentHiddenByDefault: Bool

    /// Mutável: se true, intent é visível NESTE turno mesmo se `intentHiddenByDefault=true`.
    /// Setado por CardEffect.revealAllIntents. Reseta no início do turno do player.
    public var intentRevealedThisTurn: Bool

    // MARK: - Boss multi-phase system (opt-in)

    /// Padrões de intent por fase. Se nil, boss não tem fases (comporta-se normal).
    /// Ex: [phase1Pattern, phase2Pattern, phase3Pattern] pra boss de 3 fases.
    public let phasePatterns: [IntentPattern]?

    /// HP thresholds (0.0 a 1.0) pra ativar próxima fase.
    /// count = phasePatterns.count - 1. Boss começa em phase 0 sempre.
    ///
    /// Ex: [0.66, 0.33] com 3 phases:
    /// - HP > 66%: phase 0
    /// - HP <= 66%: phase 1
    /// - HP <= 33%: phase 2
    public let phaseThresholds: [Double]?

    /// Narrativa de transição pra cada fase (mostrada como banner na UI).
    /// count = phasePatterns.count. Index 0 = ao começar combate (opcional).
    /// Index N = ao entrar phase N.
    public let phaseIntros: [String]?

    /// Estado dinâmico: qual fase o boss está agora (0 = primeira).
    public var currentPhaseIndex: Int

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        name: String,
        maxHP: Int,
        intentPattern: IntentPattern,
        flavor: String = "",
        artFilename: String? = nil,
        phasePatterns: [IntentPattern]? = nil,
        phaseThresholds: [Double]? = nil,
        phaseIntros: [String]? = nil,
        intentHiddenByDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.maxHP = maxHP
        self.hp = maxHP
        self.intentPattern = intentPattern
        self.turnsCompleted = 0
        self.statusEffects = [:]
        self.skipNextTurn = false
        self.flavor = flavor
        self.artFilename = artFilename
        self.phasePatterns = phasePatterns
        self.phaseThresholds = phaseThresholds
        self.phaseIntros = phaseIntros
        self.currentPhaseIndex = 0
        self.intentHiddenByDefault = intentHiddenByDefault
        self.intentRevealedThisTurn = false

        // Validações defensivas em debug
        if let patterns = phasePatterns, let thresholds = phaseThresholds {
            assert(thresholds.count == patterns.count - 1,
                   "phaseThresholds deve ter N-1 elementos pra N fases")
        }
    }

    // MARK: - Queries

    public var isAlive: Bool { hp > 0 }

    public var isBoss: Bool { phasePatterns != nil }

    /// True se o intent deve ficar oculto agora (ainda não revelado neste turno).
    public var isIntentHidden: Bool {
        intentHiddenByDefault && !intentRevealedThisTurn
    }

    /// A intenção que este inimigo vai executar no próximo turno dele.
    /// Se for boss, usa o pattern da fase atual.
    public var currentIntent: EnemyIntent {
        if skipNextTurn { return .skip }
        let pattern = phasePatterns?[currentPhaseIndex] ?? intentPattern
        return pattern.intent(forTurn: turnsCompleted)
    }

    // MARK: - Phase transition (bosses only)

    /// Verifica se HP entrou em nova fase. Se sim, atualiza `currentPhaseIndex`
    /// e retorna o novo index + intro text. Nil se não mudou nada.
    ///
    /// Chamada após qualquer dano no inimigo (`GameEngine.damageEnemy`).
    public mutating func checkPhaseTransition() -> (newPhase: Int, intro: String?)? {
        guard let thresholds = phaseThresholds, isAlive else { return nil }

        let hpFraction = Double(hp) / Double(maxHP)

        // Determina qual fase deveria estar dado o HP atual.
        // thresholds em ORDEM DECRESCENTE de HP: [0.66, 0.33]
        // - hp > 0.66 → phase 0
        // - hp <= 0.66 → phase 1
        // - hp <= 0.33 → phase 2
        var targetPhase = 0
        for (i, threshold) in thresholds.enumerated() {
            if hpFraction <= threshold {
                targetPhase = i + 1
            }
        }

        // Só transiciona pra fase MAIS AVANÇADA — nunca volta atrás
        if targetPhase > currentPhaseIndex {
            currentPhaseIndex = targetPhase
            let intro = phaseIntros.flatMap { $0.indices.contains(targetPhase) ? $0[targetPhase] : nil }
            return (targetPhase, intro)
        }
        return nil
    }
}
