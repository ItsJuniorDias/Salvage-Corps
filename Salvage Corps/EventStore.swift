//
//  EventStore.swift
//  Salvage Corps
//
//  Loader app-side dos eventos localizados. No init, carrega
//  `events_<idioma>.json` do bundle e injeta no `EventCatalog` do core via
//  `setOverride(fixed:procedural:)`. Se falhar, EventCatalog usa embedded
//  pt-BR (backward compat sem crash).
//
//  Idioma escolhido via `Bundle.main.preferredLocalizations.first`.
//  Mesmo mecanismo do DialogueEngine — consistente.
//

import Foundation
import SalvageCore

enum EventStore {

    /// Payload que corresponde ao formato dos JSONs no bundle.
    private struct Catalog: Decodable {
        let fixed: [GameEvent]
        let procedural: [GameEvent]
    }

    /// Chamado no startup do app. Idempotente — chame quantas vezes quiser.
    static func loadAndInject() {
        let preferred = Bundle.main.preferredLocalizations.first ?? "en"

        // Candidatos em ordem de preferência (mesma lógica do DialogueEngine)
        var candidates: [String] = ["events_\(preferred)"]
        if preferred.hasPrefix("en") && preferred != "en" {
            candidates.append("events_en")
        }
        if preferred.hasPrefix("es") && preferred != "es" {
            candidates.append("events_es")
        }
        if preferred.hasPrefix("pt") && preferred != "pt-BR" {
            candidates.append("events_pt-BR")
        }
        candidates.append("events_en")     // fallback
        candidates.append("events_pt-BR")  // source

        for name in candidates {
            if let catalog = tryLoadCatalog(named: name) {
                EventCatalog.setOverride(
                    fixed: catalog.fixed,
                    procedural: catalog.procedural
                )
                print("EventStore: carregado \(name).json — fixed=\(catalog.fixed.count), proc=\(catalog.procedural.count) (idioma: \(preferred))")
                return
            }
        }
        print("EventStore: NENHUM catálogo de eventos encontrado — usando embedded pt-BR fallback")
    }

    private static func tryLoadCatalog(named name: String) -> Catalog? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Catalog.self, from: data)
        } catch {
            print("EventStore: erro parsing \(name).json — \(error)")
            return nil
        }
    }
}
