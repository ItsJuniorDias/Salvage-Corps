import Foundation

/// Estado persistente do deck do player dentro de uma run.
///
/// Trackea 2 dimensões:
/// - `upgradesByTemplate`: qual cicatriz foi aplicada em qual template starter
/// - `extraCards`: templateIDs de cartas ADICIONADAS via eventos (Ato 2+).
///   Podem ser upgraded normalmente também.
///
/// Persistido via MapStore junto com RunPlayerState.
public struct PlayerDeck: Codable, Equatable, Sendable {

    /// Mapping templateID → upgradeID escolhido.
    /// Ex: ["order_shoot": "order_shoot_a", "gas_release": "gas_release_a"]
    public private(set) var upgradesByTemplate: [String: String]

    /// templateIDs de cartas EXTRA no deck (não presentes no starter).
    /// Podem ter cópias múltiplas — cada string = 1 cópia.
    /// Ex: ["silent_reserve", "gas_release", "silent_reserve"] = 2 Silenciosas + 1 Gás
    public private(set) var extraCards: [String]

    public init(
        upgradesByTemplate: [String: String] = [:],
        extraCards: [String] = []
    ) {
        self.upgradesByTemplate = upgradesByTemplate
        self.extraCards = extraCards
    }

    // MARK: - Mutations

    public mutating func applyUpgrade(templateID: String, upgradeID: String) {
        upgradesByTemplate[templateID] = upgradeID
    }

    public mutating func removeUpgrade(templateID: String) {
        upgradesByTemplate.removeValue(forKey: templateID)
    }

    public mutating func addExtraCard(templateID: String) {
        extraCards.append(templateID)
    }

    public mutating func reset() {
        upgradesByTemplate.removeAll()
        extraCards.removeAll()
    }

    // MARK: - Queries

    public func upgradeIDFor(templateID: String) -> String? {
        upgradesByTemplate[templateID]
    }

    public func hasUpgrade(templateID: String) -> Bool {
        upgradesByTemplate[templateID] != nil
    }

    public var upgradeCount: Int { upgradesByTemplate.count }

    public var extraCardCount: Int { extraCards.count }

    /// Retorna templateIDs únicos de extra cards (dedup).
    public var uniqueExtraTemplateIDs: [String] {
        Array(Set(extraCards)).sorted()
    }
}
