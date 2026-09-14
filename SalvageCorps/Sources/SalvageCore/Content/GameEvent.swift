import Foundation

// ============================================================================
// MARK: - GameEvent
// ============================================================================

/// Um evento narrativo no mapa.
///
/// Dois modos:
/// - **Fixed**: tem `narrativeID` que bate com `MapNode.narrativeID`.
///   Aparece sempre no mesmo lugar da progressão (ex: "petrov_warning" col 2).
/// - **Procedural**: `narrativeID` = nil. Pode aparecer em qualquer `.event`
///   node sem narrativeID definido — pick determinístico pelo UUID.
public struct GameEvent: Identifiable, Codable, Equatable, Sendable {

    public let id: String
    public let act: Int
    public let title: String
    public let narrative: String              // Texto principal, italic
    public let backgroundArt: String?         // Asset name, fallback bg_no_mans_land
    public let choices: [EventChoice]
    public let narrativeID: String?           // Se != nil, evento fixed

    public init(
        id: String,
        act: Int,
        title: String,
        narrative: String,
        backgroundArt: String? = nil,
        choices: [EventChoice],
        narrativeID: String? = nil
    ) {
        self.id = id
        self.act = act
        self.title = title
        self.narrative = narrative
        self.backgroundArt = backgroundArt
        self.choices = choices
        self.narrativeID = narrativeID
    }
}

// ============================================================================
// MARK: - EventChoice
// ============================================================================

/// Uma escolha dentro de um evento.
public struct EventChoice: Identifiable, Codable, Equatable, Sendable {

    public let id: String
    public let label: String                  // Botão: "Escutar Petrov"
    public let costHint: String?              // Preview de custo/ganho: "-3 HP · +5 Moral"
    public let effects: [EventEffect]
    public let resultText: String             // Narrativa após escolha

    public init(
        id: String,
        label: String,
        costHint: String? = nil,
        effects: [EventEffect],
        resultText: String
    ) {
        self.id = id
        self.label = label
        self.costHint = costHint
        self.effects = effects
        self.resultText = resultText
    }
}

// ============================================================================
// MARK: - EventEffect
// ============================================================================

/// Efeitos que uma escolha pode aplicar.
///
/// Simplicidade proposital: HP/Moral, cicatrizes forçadas, e adição de cartas.
/// Remoção de cartas fica pra futuro (mais complexo — precisa UI de picker).
public enum EventEffect: Codable, Equatable, Hashable, Sendable {

    /// Muda HP atual (positivo = cura, negativo = dano). Clamped ao maxHP.
    case gainHP(Int)

    /// Muda Moral atual (positivo = ganho, negativo = perda). Clamped ao maxMoral.
    case gainMoral(Int)

    /// Muda maxHP permanentemente pra essa run. Também ajusta HP atual pra
    /// manter proporção (se +5 max, +5 no atual).
    case gainMaxHP(Int)

    /// Muda maxMoral permanentemente pra essa run. Também ajusta atual.
    case gainMaxMoral(Int)

    /// Força cicatriz específica em uma carta. Sobrescreve upgrade prévio.
    case applyScar(templateID: String, upgradeID: String)

    /// Adiciona uma carta ao deck (extras). templateID precisa existir em
    /// `StarterDeck.extraCardTemplate(for:)`.
    case addCard(templateID: String)

    // MARK: - Codable (custom pra JSON legível em events_*.json)

    private enum CodingKeys: String, CodingKey {
        case type, value, templateID, upgradeID
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gainHP(let n):
            try c.encode("gainHP", forKey: .type)
            try c.encode(n, forKey: .value)
        case .gainMoral(let n):
            try c.encode("gainMoral", forKey: .type)
            try c.encode(n, forKey: .value)
        case .gainMaxHP(let n):
            try c.encode("gainMaxHP", forKey: .type)
            try c.encode(n, forKey: .value)
        case .gainMaxMoral(let n):
            try c.encode("gainMaxMoral", forKey: .type)
            try c.encode(n, forKey: .value)
        case .applyScar(let t, let u):
            try c.encode("applyScar", forKey: .type)
            try c.encode(t, forKey: .templateID)
            try c.encode(u, forKey: .upgradeID)
        case .addCard(let t):
            try c.encode("addCard", forKey: .type)
            try c.encode(t, forKey: .templateID)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "gainHP":       self = .gainHP(try c.decode(Int.self, forKey: .value))
        case "gainMoral":    self = .gainMoral(try c.decode(Int.self, forKey: .value))
        case "gainMaxHP":    self = .gainMaxHP(try c.decode(Int.self, forKey: .value))
        case "gainMaxMoral": self = .gainMaxMoral(try c.decode(Int.self, forKey: .value))
        case "applyScar":
            self = .applyScar(
                templateID: try c.decode(String.self, forKey: .templateID),
                upgradeID: try c.decode(String.self, forKey: .upgradeID)
            )
        case "addCard":
            self = .addCard(templateID: try c.decode(String.self, forKey: .templateID))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "EventEffect desconhecido: \(type)"
            )
        }
    }
}
