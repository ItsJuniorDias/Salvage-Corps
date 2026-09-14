import Foundation

/// Uma sequência de linhas de diálogo com um NPC.
///
/// Estrutura JSON esperada (em `dialogues.json`):
/// ```
/// {
///   "dialogues": [
///     {
///       "id": "petrov_1",
///       "npc": "petrov",
///       "act": 1,
///       "lines": [
///         { "speaker": "PETROV", "text": "..." },
///         { "speaker": "EDMUND", "text": "..." },
///         { "speaker": "NARRADOR", "text": "..." }
///       ]
///     }
///   ]
/// }
/// ```
public struct Dialogue: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let npc: NPC
    public let act: Int
    public let lines: [DialogueLine]

    public init(id: String, npc: NPC, act: Int, lines: [DialogueLine]) {
        self.id = id
        self.npc = npc
        self.act = act
        self.lines = lines
    }
}

public struct DialogueLine: Codable, Sendable, Equatable {
    public let speaker: String
    public let text: String

    public init(speaker: String, text: String) {
        self.speaker = speaker
        self.text = text
    }
}

/// Root container do JSON.
public struct DialogueCatalog: Codable, Sendable {
    public let dialogues: [Dialogue]

    public init(dialogues: [Dialogue]) {
        self.dialogues = dialogues
    }
}

extension DialogueCatalog {

    /// Retorna todos os diálogos de um NPC em um ato específico.
    public func dialogues(for npc: NPC, act: Int) -> [Dialogue] {
        dialogues.filter { $0.npc == npc && $0.act == act }
    }

    /// Escolhe um diálogo determinístico pra um NPC dado um seed.
    /// Rotaciona pelos diálogos disponíveis desse NPC nesse ato.
    public func pickDialogue(for npc: NPC, act: Int, seed: UInt64) -> Dialogue? {
        let candidates = dialogues(for: npc, act: act)
        guard !candidates.isEmpty else { return nil }
        let index = Int(seed % UInt64(candidates.count))
        return candidates[index]
    }
}
