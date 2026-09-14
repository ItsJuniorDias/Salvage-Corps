//
//  DeckStore.swift
//  Salvage Corps
//
//  Fase 8: persistência do deck PvP do usuário em UserDefaults.
//  Singleton @Observable — reactive pra UI.
//

import Foundation
import Observation
import SalvageCore

@Observable
@MainActor
final class DeckStore {

    static let shared = DeckStore()

    /// Config atual do deck do usuário. Escreve em UserDefaults automaticamente
    /// no setter — apenas quando o valor mudar (evita I/O desnecessário).
    var currentDeck: DuelDeckConfig {
        didSet {
            guard currentDeck != oldValue else { return }
            persist()
        }
    }

    private static let userDefaultsKey = "sc.duel.deckConfig.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let loaded = try? JSONDecoder().decode(DuelDeckConfig.self, from: data) {
            self.currentDeck = loaded
        } else {
            self.currentDeck = DuelDeckConfig.starterEdmund
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(currentDeck) else {
            print("[DeckStore] Falha ao encodar deck")
            return
        }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }

    /// Reseta pro deck default (starter Edmund).
    func resetToDefault() {
        currentDeck = DuelDeckConfig.starterEdmund
    }

    /// Materializa `[Card]` com UUIDs frescos pro deck atual. Chame toda vez
    /// que iniciar um duelo — nunca reuse instâncias.
    /// Se o deck salvo estiver inválido (por algum motivo — arquivo corrompido,
    /// migração), retorna o default como fallback seguro.
    func cardsForCurrentDuel() -> [Card] {
        let config = currentDeck.isValid ? currentDeck : DuelDeckConfig.starterEdmund
        return config.toCardList()
    }
}
