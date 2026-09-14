//
//  DialogueEngine.swift
//  Salvage Corps
//
//  Carrega dialogues.json do bundle uma única vez (singleton) e oferece
//  API pra buscar diálogos por NPC/ato. View de dialogue usa isso.
//

import Foundation
import SalvageCore

final class DialogueEngine {

    static let shared = DialogueEngine()

    private(set) var catalog: DialogueCatalog

    private init() {
        self.catalog = DialogueEngine.loadFromBundle() ?? DialogueCatalog(dialogues: [])
        print("DialogueEngine: \(catalog.dialogues.count) diálogos carregados")
    }

    /// Carrega dialogues do bundle. Tenta na ordem:
    /// 1. `dialogues_<preferredLanguage>.json` (ex: dialogues_en.json)
    /// 2. `dialogues_pt-BR.json` (source original)
    /// 3. `dialogues.json` (fallback legado)
    private static func loadFromBundle() -> DialogueCatalog? {
        let preferred = Bundle.main.preferredLocalizations.first ?? "pt-BR"

        // Constrói lista de candidatos em ordem de preferência
        var candidates: [String] = ["dialogues_\(preferred)"]
        // Normaliza en-US → en, pt-PT → pt-BR fallback
        if preferred.hasPrefix("en") && preferred != "en" {
            candidates.append("dialogues_en")
        }
        if preferred.hasPrefix("es") && preferred != "es" {
            candidates.append("dialogues_es")
        }
        if preferred.hasPrefix("pt") && preferred != "pt-BR" {
            candidates.append("dialogues_pt-BR")
        }
        candidates.append("dialogues_pt-BR")  // source
        candidates.append("dialogues")        // fallback legado

        for name in candidates {
            if let catalog = tryLoadCatalog(named: name) {
                print("DialogueEngine: carregado \(name).json (idioma preferido: \(preferred))")
                return catalog
            }
        }
        print("DialogueEngine: NENHUM catálogo de diálogos encontrado no bundle")
        return nil
    }

    private static func tryLoadCatalog(named name: String) -> DialogueCatalog? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(DialogueCatalog.self, from: data)
        } catch {
            print("DialogueEngine: erro parsing \(name).json — \(error)")
            return nil
        }
    }

    // MARK: - Queries

    /// Deriva até 2 NPCs disponíveis em um camp específico. Determinístico pelo UUID.
    ///
    /// Filtra:
    /// - NPCs marcados como `isSpecialAppearance` (ex: Henry) — esses aparecem
    ///   apenas por regra explícita da view (ver `CampView.availableNPCs`).
    /// - NPCs que NÃO têm nenhum diálogo carregado para o `act` atual — evita
    ///   mostrar um nome no picker que abre nada quando clicado.
    func availableNPCs(forNodeID nodeID: UUID, act: Int) -> [NPC] {
        // Só entra no pool aleatório quem tem diálogo no ato E não é special.
        let pool = NPC.allCases.filter { npc in
            !npc.isSpecialAppearance
                && !catalog.dialogues(for: npc, act: act).isEmpty
        }
        guard !pool.isEmpty else { return [] }

        // Hash do UUID pra seed — sorteio determinístico por nó.
        let seed = UInt64(bitPattern: Int64(nodeID.hashValue))
        var rng = SeededRandom(seed: seed == 0 ? 1 : seed)
        let shuffled = pool.shuffled(using: &rng)
        return Array(shuffled.prefix(2))
    }

    /// Overload legado — mantido pra compat caso alguma view antiga chame sem `act`.
    /// Assume ato 1 se não informado. NÃO use em código novo.
    @available(*, deprecated, message: "Use availableNPCs(forNodeID:act:) — precisa do ato pra filtrar quem tem diálogo.")
    func availableNPCs(forNodeID nodeID: UUID) -> [NPC] {
        availableNPCs(forNodeID: nodeID, act: 1)
    }

    /// Escolhe qual diálogo mostrar pra um NPC em um camp específico.
    /// Determinístico pelo nodeID + npc, então rejogar mesmo camp mostra mesma conversa.
    func pickDialogue(for npc: NPC, act: Int, atNodeID nodeID: UUID) -> Dialogue? {
        let combined = "\(nodeID.uuidString):\(npc.rawValue)"
        let seed = UInt64(bitPattern: Int64(combined.hashValue))
        return catalog.pickDialogue(for: npc, act: act, seed: seed)
    }
}
