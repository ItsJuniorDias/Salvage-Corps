import Foundation

/// Operações jogáveis do Ato 1.
///
/// Cada operação representa um combate único com narrativa, dificuldade
/// e composição de inimigos. A ORDEM do enum define a progressão linear
/// (jogador precisa completar a anterior pra desbloquear a próxima).
///
/// Value type: os dados aqui são metadados fixos. Estado de progressão
/// (o que já foi completado) vive em `PlayerProgress`.
public enum Operation: String, Codable, CaseIterable, Identifiable, Sendable {

    case patrulhaRotina
    case assaltoNinho
    case incidenteTrincheira47
    case contatoDireto

    public var id: String { rawValue }

    /// Índice na ordem de progressão (0 = primeira, allCases.count-1 = última).
    public var order: Int {
        Operation.allCases.firstIndex(of: self) ?? 0
    }

    public var title: String {
        switch self {
        case .patrulhaRotina: return "Patrulha de Rotina"
        case .assaltoNinho: return "Assalto ao Ninho"
        case .incidenteTrincheira47: return "Incidente na Trincheira 47"
        case .contatoDireto: return "Contato Direto"
        }
    }

    public var subtitle: String {
        switch self {
        case .patrulhaRotina: return "2 Recrutas Alemães"
        case .assaltoNinho: return "Recruta + Metralhadora"
        case .incidenteTrincheira47: return "Recruta + Metralhadora + Traumatizado"
        case .contatoDireto: return "Oficial Alemão · Boss Ato 1"
        }
    }

    public var difficultyStars: String {
        switch self {
        case .patrulhaRotina: return "★☆☆"
        case .assaltoNinho: return "★★☆"
        case .incidenteTrincheira47: return "★★★"
        case .contatoDireto: return "☠"
        }
    }

    public var isBoss: Bool {
        self == .contatoDireto
    }

    /// Frase narrativa curta mostrada antes/durante o combate.
    public var narrativeIntro: String {
        switch self {
        case .patrulhaRotina:
            return "Uma patrulha rotineira. Deveria ser."
        case .assaltoNinho:
            return "Silenciar a metralhadora. Recuperar corpos, se possível."
        case .incidenteTrincheira47:
            return "Algo aconteceu na trincheira 47. Ninguém sabe o quê."
        case .contatoDireto:
            return "Hauptmann Krüger viu coisas. Precisa ser silenciado."
        }
    }

    /// Constrói o encontro de combate correspondente.
    public func makeEnemies() -> [Enemy] {
        switch self {
        case .patrulhaRotina: return StarterEnemies.encounterEasy()
        case .assaltoNinho: return StarterEnemies.encounterMedium()
        case .incidenteTrincheira47: return StarterEnemies.encounterHard()
        case .contatoDireto: return StarterEnemies.encounterBoss()
        }
    }
}
