import Foundation

/// NPCs disponíveis ao longo do jogo. Cada camp mostra 2 deles determinístico.
///
/// Voz de cada personagem (importante pra dialogue writing consistente):
/// - Petrov: russo, veterano do Front Oriental, sabe demais, warnings constantes
/// - Wren: médica sardônica, dark humor, prática, ganchos emocionais escondidos
/// - Ashcroft: historiador/scholar, referências obscuras, condenação pelo saber
/// - Wardell: veterano cínico, crítica militar, "vi coisas piores"
/// - Henry: irmão morto do Edmund, aparece SILENCIOSAMENTE no camp Ato 3.
///          Não deveria estar ali. Nunca fala mais de 3-4 palavras por diálogo.
public enum NPC: String, Codable, CaseIterable, Sendable, Identifiable {
    case petrov
    case wren
    case ashcroft
    case wardell
    case henry

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .petrov:   return "Sgto. Petrov"
        case .wren:     return "Dra. Wren"
        case .ashcroft: return "Cap. Ashcroft"
        case .wardell:  return "Cabo Wardell"
        case .henry:    return "…"
        }
    }

    /// Nome curto pra header de diálogo.
    public var shortName: String {
        switch self {
        case .petrov:   return "PETROV"
        case .wren:     return "WREN"
        case .ashcroft: return "ASHCROFT"
        case .wardell:  return "WARDELL"
        case .henry:    return "…"
        }
    }

    /// Papel na unidade.
    public var role: String {
        switch self {
        case .petrov:   return "Sargento · veterano"
        case .wren:     return "Médica de campo"
        case .ashcroft: return "Inteligência · historiador"
        case .wardell:  return "Cabo · atirador"
        case .henry:    return "…"
        }
    }

    /// Nome do arquivo de arte no Assets.xcassets (imageset).
    public var artFilename: String {
        switch self {
        case .petrov:   return "npc_petrov"
        case .wren:     return "npc_wren"
        case .ashcroft: return "npc_ashcroft"
        case .wardell:  return "npc_wardell"
        case .henry:    return "npc_henry"
        }
    }

    /// True se este NPC só deve aparecer em condições especiais (não integra
    /// pool normal do camp). Usado pelo DialogueEngine.
    public var isSpecialAppearance: Bool {
        self == .henry
    }
}
