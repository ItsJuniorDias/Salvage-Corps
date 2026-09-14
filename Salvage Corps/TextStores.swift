//
//  TextStores.swift
//  Salvage Corps
//
//  Loaders app-side pra terminal_*.json e endings_*.json. Mesmo pattern do
//  EventStore e DialogueEngine — escolhe idioma preferido, fallback pt-BR.
//

import Foundation

// ============================================================================
// MARK: - TerminalTextStore
// ============================================================================

/// Textos de fim-de-ato (título, narrativa) + labels/costs/results das 9
/// escolhas terminais. Consumido pela TerminalChoiceView.
enum TerminalTextStore {

    struct ActText: Decodable {
        let title: String
        let narrative: String
    }

    struct ChoiceText: Decodable {
        let label: String
        let costHint: String
        let resultText: String
    }

    struct Catalog: Decodable {
        let acts: [String: ActText]         // "1" / "2" / "3"
        let choices: [String: ChoiceText]   // TerminalChoice.rawValue
    }

    /// Catálogo carregado. Nil se falhar todo o loader — caller trata com defaults.
    static private(set) var catalog: Catalog?

    static func loadForCurrentLanguage() {
        catalog = loadCatalog(prefix: "terminal")
        if catalog != nil {
            print("TerminalTextStore: catálogo carregado (\(catalog!.acts.count) atos, \(catalog!.choices.count) escolhas)")
        }
    }

    static func act(_ act: Int) -> ActText? {
        catalog?.acts[String(act)]
    }

    static func choice(_ id: String) -> ChoiceText? {
        catalog?.choices[id]
    }
}

// ============================================================================
// MARK: - EndingTextStore
// ============================================================================

/// Textos dos 5 endings (narrativa longa de ~300 palavras). Consumido pela
/// EndingView.
enum EndingTextStore {

    struct EndingText: Decodable {
        let endingText: String
    }

    struct Catalog: Decodable {
        let endings: [String: EndingText]  // EndingPath.rawValue
    }

    static private(set) var catalog: Catalog?

    static func loadForCurrentLanguage() {
        catalog = loadCatalog(prefix: "endings")
        if catalog != nil {
            print("EndingTextStore: catálogo carregado (\(catalog!.endings.count) endings)")
        }
    }

    static func ending(_ id: String) -> EndingText? {
        catalog?.endings[id]
    }
}

// ============================================================================
// MARK: - Shared loader helper
// ============================================================================

/// Loader genérico. Tenta `<prefix>_<lang>.json` com fallback normalizado
/// (en-US → en, etc), depois `<prefix>_pt-BR.json`.
private func loadCatalog<T: Decodable>(prefix: String) -> T? {
    let preferred = Bundle.main.preferredLocalizations.first ?? "pt-BR"

    var candidates: [String] = ["\(prefix)_\(preferred)"]
    if preferred.hasPrefix("en") && preferred != "en" {
        candidates.append("\(prefix)_en")
    }
    if preferred.hasPrefix("es") && preferred != "es" {
        candidates.append("\(prefix)_es")
    }
    if preferred.hasPrefix("pt") && preferred != "pt-BR" {
        candidates.append("\(prefix)_pt-BR")
    }
    candidates.append("\(prefix)_pt-BR")

    for name in candidates {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            continue
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(T.self, from: data)
            return catalog
        } catch {
            print("Store: erro parsing \(name).json — \(error)")
        }
    }
    print("Store: nenhum catálogo \(prefix)_*.json encontrado")
    return nil
}
