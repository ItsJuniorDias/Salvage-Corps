import Foundation

/// Uma carta jogável.
///
/// Value type (struct): cada cópia no deck é independente. Isso é essencial
/// pra evitar bugs onde modificar uma carta afeta outras cópias dela.
///
/// A `id` é única por INSTÂNCIA (não por tipo/nome). Uma carta "Ordem: Atirar"
/// no deck e outra "Ordem: Atirar" na mão têm IDs diferentes. Isso permite
/// rastrear a mesma carta ao longo do combate (importante pro sistema de
/// cicatrizes que virá depois — cada carta acumula usos individualmente).
public struct Card: Identifiable, Equatable, Hashable, Codable {

    public let id: UUID
    public let name: String
    public let cost: Int
    public let type: CardType
    public let effects: [CardEffect]
    public let targeting: CardTargeting
    public let flavor: String

    /// ID estável do template desta carta (ex: "order_shoot", "close_formation").
    /// Cards com mesmo templateID compartilham o mesmo pool de upgrades.
    /// Nil = carta sem sistema de cicatrizes (raro, ex: cartas geradas dinamicamente).
    public let templateID: String?

    /// Nome do arquivo de arte (sem extensão) no Asset Catalog / bundle.
    /// Ex: "card_ordem_atirar". Nil = usa placeholder.
    public let artFilename: String?

    /// Se true, vai pro exílio no fim do turno em vez do descarte.
    public let exhaustAfterPlay: Bool

    /// Se true, não vai pro descarte no fim do turno — fica retida na mão.
    public let retain: Bool

    /// Cicatrizes acumuladas nesta instância específica.
    /// Cada upgrade aplicado adiciona seu ID aqui.
    public var scars: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        cost: Int,
        type: CardType,
        effects: [CardEffect],
        targeting: CardTargeting = .none,
        flavor: String = "",
        templateID: String? = nil,
        artFilename: String? = nil,
        exhaustAfterPlay: Bool = false,
        retain: Bool = false,
        scars: [String] = []
    ) {
        self.id = id
        self.name = name
        self.cost = cost
        self.type = type
        self.effects = effects
        self.targeting = targeting
        self.flavor = flavor
        self.templateID = templateID
        self.artFilename = artFilename
        self.exhaustAfterPlay = exhaustAfterPlay
        self.retain = retain
        self.scars = scars
    }
}


public enum CardType: String, Equatable, Hashable, Codable {
    case ordem       // Ataque direto
    case manobra     // Bloqueio / posição / utilidade
    case resolucao   // Recuperação de Moral / buffs mentais
    case corrupcao   // Alto poder, alto custo em Moral ou cicatriz forçada
    case eco         // (Futuro) Cartas que replicam eventos passados
}
