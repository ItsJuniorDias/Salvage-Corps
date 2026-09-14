import Foundation

/// Um caminho de upgrade (cicatriz) pra uma carta.
///
/// Modelo diff-based: só carrega o que MUDA em relação à carta base.
/// Fields nil = mantém original.
///
/// Cada carta tem 2 paths disponíveis (A e B), definidos em `UpgradeCatalog`.
/// Escolhas ficam no `PlayerDeck` (persistido no MapStore).
public struct CardUpgrade: Codable, Equatable, Hashable, Sendable, Identifiable {

    public let id: String                    // "order_shoot_a", "order_shoot_b"
    public let name: String                  // Novo nome da carta upgraded
    public let shortDescription: String      // Texto descritivo, tipo "9 dano" pra UI
    public let flavorText: String            // Frase temática

    // Overrides opcionais — nil = mantém original da carta base
    public let cost: Int?
    public let effects: [CardEffect]?
    public let targeting: CardTargeting?
    public let exhaustAfterPlay: Bool?
    public let retain: Bool?

    public init(
        id: String,
        name: String,
        shortDescription: String,
        flavorText: String = "",
        cost: Int? = nil,
        effects: [CardEffect]? = nil,
        targeting: CardTargeting? = nil,
        exhaustAfterPlay: Bool? = nil,
        retain: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.shortDescription = shortDescription
        self.flavorText = flavorText
        self.cost = cost
        self.effects = effects
        self.targeting = targeting
        self.exhaustAfterPlay = exhaustAfterPlay
        self.retain = retain
    }
}

// MARK: - Card extension

extension Card {

    /// Retorna nova Card com o upgrade aplicado.
    /// Preserva id, tipo, arte, flavor original — troca só o que o upgrade sobrescreve.
    /// Adiciona o upgrade.id ao array `scars` pra rastreabilidade.
    public func applyingUpgrade(_ upgrade: CardUpgrade) -> Card {
        Card(
            id: self.id,
            name: upgrade.name,
            cost: upgrade.cost ?? self.cost,
            type: self.type,
            effects: upgrade.effects ?? self.effects,
            targeting: upgrade.targeting ?? self.targeting,
            flavor: upgrade.flavorText.isEmpty ? self.flavor : upgrade.flavorText,
            artFilename: self.artFilename,
            exhaustAfterPlay: upgrade.exhaustAfterPlay ?? self.exhaustAfterPlay,
            retain: upgrade.retain ?? self.retain,
            scars: self.scars + [upgrade.id]
        )
    }
}
