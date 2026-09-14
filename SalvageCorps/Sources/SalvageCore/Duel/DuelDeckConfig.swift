import Foundation

/// Configuração compacta de um deck PvP: `templateID` → quantidade de cópias.
///
/// Serializável (Codable) pra guardar em UserDefaults do lado do app iOS. Cabe em
/// poucos bytes — muito menor que serializar `[Card]` completo (que tem UUID,
/// name, effects, flavor por cópia).
///
/// **Fluxo esperado**:
/// 1. UI (DeckBuilderView) constrói/edita `DuelDeckConfig`
/// 2. Validação via `validate()`
/// 3. Ao entrar num duelo, `toCardList()` transforma em `[Card]` com UUIDs frescos
/// 4. `DuelFactory.createHostedDuel(...)` recebe esse `[Card]` como deck do host
///
/// **Limites MVP** (pool starter Edmund):
/// - Tamanho fixo: `deckSize = 15` cartas
/// - Máximo: `maxCopiesPerTemplate = 2` cópias por template
/// - Pool: 8 templates do starter Edmund (`allowedTemplates`)
///
/// Fase 9+ pode expandir com cartas extras curadas pra PvP.
public struct DuelDeckConfig: Codable, Equatable {

    /// Quantidade de cópias por templateID. Valores 0 são omitidos por convenção.
    public var counts: [String: Int]

    public init(counts: [String: Int] = [:]) {
        // Filtra zeros pra manter estrutura enxuta
        self.counts = counts.filter { $0.value > 0 }
    }

    // MARK: - Constantes MVP

    public static let deckSize: Int = 15
    public static let maxCopiesPerTemplate: Int = 2

    /// Templates permitidos no pool PvP MVP. Ordem estável — usada em UIs
    /// e no `toCardList()` pra que o deck seja construído em ordem previsível
    /// antes do embaralhamento.
    public static let allowedTemplates: [String] = [
        "order_shoot",      // Ordem: Atirar — 1 energia, damage 6
        "close_formation",  // Formação Fechada — 1 energia, block 5
        "counter_attack",   // Contra-Ataque — 1 energia, damage 3 + block 3
        "push_forward",     // Empurrar Frente — 1 energia, skipNextTurn (STRONG em PvP)
        "reinforce_moral",  // Reforçar Moral — 1 energia, +5 moral
        "rationalize",      // Racionalizar — 0 energia, exhaust + moral 3
        "order_shout",      // Grito de Ordem — 2 energia, damage 4 + fear 2
        "order_retreat",    // Ordem: Recuar — 2 energia, block 8
    ]

    // MARK: - Default (starter Edmund adaptado pra 15 cartas)

    /// Deck padrão do MVP — replica o starter Edmund e completa até 15 cartas
    /// duplicando as básicas. Balanceamento inicial "seguro" pra novos jogadores.
    public static let starterEdmund: DuelDeckConfig = DuelDeckConfig(counts: [
        "order_shoot":      2,  // 2 dano single-target
        "close_formation":  2,  // 2 block
        "counter_attack":   2,  // 2 dano+block
        "push_forward":     2,  // 2 skip (upgrade do single: single tem 1)
        "reinforce_moral":  2,  // 2 moral (upgrade: single tem 1)
        "rationalize":      2,  // 2 remove-carta
        "order_shout":      1,  // 1 AoE
        "order_retreat":    2,  // 2 big-block (upgrade: single tem 1)
    ])
    // Total: 2+2+2+2+2+2+1+2 = 15 ✓

    // MARK: - Queries

    /// Total de cartas no deck (soma de todas as counts).
    public var totalCards: Int {
        counts.values.reduce(0, +)
    }

    /// Retorna a count pra um template, 0 se ausente.
    public func count(for templateID: String) -> Int {
        counts[templateID] ?? 0
    }

    // MARK: - Mutations

    public mutating func setCount(_ n: Int, for templateID: String) {
        let clamped = max(0, min(Self.maxCopiesPerTemplate, n))
        if clamped == 0 {
            counts.removeValue(forKey: templateID)
        } else {
            counts[templateID] = clamped
        }
    }

    public mutating func increment(_ templateID: String) {
        setCount(count(for: templateID) + 1, for: templateID)
    }

    public mutating func decrement(_ templateID: String) {
        setCount(count(for: templateID) - 1, for: templateID)
    }

    // MARK: - Validation

    public enum ValidationError: Error, Equatable {
        case wrongSize(actual: Int, required: Int)
        case tooManyCopies(templateID: String, count: Int, max: Int)
        case unknownTemplate(String)
        case negativeCount(templateID: String)
    }

    /// Retorna nil se válido; senão o primeiro erro encontrado.
    public func validate() -> ValidationError? {
        if totalCards != Self.deckSize {
            return .wrongSize(actual: totalCards, required: Self.deckSize)
        }
        for (tid, count) in counts {
            if !Self.allowedTemplates.contains(tid) {
                return .unknownTemplate(tid)
            }
            if count < 0 {
                return .negativeCount(templateID: tid)
            }
            if count > Self.maxCopiesPerTemplate {
                return .tooManyCopies(templateID: tid, count: count, max: Self.maxCopiesPerTemplate)
            }
        }
        return nil
    }

    public var isValid: Bool { validate() == nil }

    // MARK: - Materialize em [Card]

    /// Constrói o `[Card]` do deck com UUIDs FRESCOS pra cada cópia. Chame toda
    /// vez que um novo duelo começar — nunca reuse instâncias de `Card` entre
    /// duelos (bugs sutis com identidade).
    ///
    /// Cartas são adicionadas na ordem de `allowedTemplates` (estável) —
    /// depois o `DuelEngine.applyStartDuel` embaralha via `SeededRandom`.
    ///
    /// Se algum templateID no config não corresponder a nenhum template
    /// conhecido (validação já deveria ter pego), é silenciosamente ignorado.
    public func toCardList() -> [Card] {
        // uniqueTemplates() retorna 1 instância por template. Precisamos
        // reconstruir com UUIDs frescos pra cada cópia — Card.id é `let`.
        let templates = StarterDeck.uniqueTemplates()
        let templateByID: [String: Card] = Dictionary(
            uniqueKeysWithValues: templates.compactMap { t in
                t.templateID.map { ($0, t) }
            }
        )

        var deck: [Card] = []
        for tid in Self.allowedTemplates {
            let n = counts[tid] ?? 0
            guard n > 0, let template = templateByID[tid] else { continue }
            for _ in 0..<n {
                deck.append(Card(
                    id: UUID(),  // ← UUID fresco pra cada cópia
                    name: template.name,
                    cost: template.cost,
                    type: template.type,
                    effects: template.effects,
                    targeting: template.targeting,
                    flavor: template.flavor,
                    templateID: template.templateID,
                    artFilename: template.artFilename,
                    exhaustAfterPlay: template.exhaustAfterPlay,
                    retain: template.retain,
                    scars: template.scars
                ))
            }
        }
        return deck
    }
}
