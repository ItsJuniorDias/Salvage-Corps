//
//  ProgressStore.swift
//  Salvage Corps
//
//  Trackea progresso ENTRE runs (atos completados, escolhas terminais,
//  endings alcançados). Estado da run atual em andamento fica no MapStore.
//
//  Storage: JSON no Documents/ com backup automático (via FileStorage).
//  Faz migração one-time de UserDefaults ao inicializar (se aplicável).
//

import Foundation
import SwiftUI
import SalvageCore

@Observable
final class ProgressStore {

    private static let filename = "progress.json"
    private static let legacyUserDefaultsKey = "salvage.progress.v1"
    private static let legacyHighestActKey = "salvage.highestAct"

    // MARK: - State

    private(set) var progress: PlayerProgress
    private(set) var highestActCompleted: Int
    private(set) var consequences: ActConsequences

    /// Meta layer state — trackea condições ocultas pro ending "O Espelho".
    /// Salvo entre runs.
    private(set) var metaState: MetaLayerState

    // MARK: - Init

    init() {
        // Tenta carregar do FileStorage primeiro
        if let payload = FileStorage.load(SavePayload.self, from: Self.filename) {
            self.progress = payload.progress
            self.highestActCompleted = payload.highestActCompleted
            self.consequences = payload.consequences
            self.metaState = payload.metaState ?? .empty
            print("ProgressStore: carregado — ato \(highestActCompleted), \(consequences.allChoices.count) escolhas, meta=\(metaState.henryEncounters) Henry / \(metaState.ghostCardsPlayed) ghost")
            return
        }

        // Migração one-time: UserDefaults → file
        let migratedProgress = FileStorage.migrateFromUserDefaults(
            PlayerProgress.self,
            userDefaultsKey: Self.legacyUserDefaultsKey,
            toFilename: "legacy_progress_only.json"  // temp, não usado
        ) ?? PlayerProgress()

        let migratedAct = UserDefaults.standard.integer(forKey: Self.legacyHighestActKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyHighestActKey)
        _ = try? FileStorage.delete("legacy_progress_only.json")

        self.progress = migratedProgress
        self.highestActCompleted = migratedAct
        self.consequences = ActConsequences()
        self.metaState = .empty

        print("ProgressStore: novo/migrado — highestAct=\(highestActCompleted)")
        persistToFile()
    }

    // MARK: - Sistema Map-first (novo)

    /// Chamado ao vencer o boss de um ato. Desbloqueia ato seguinte.
    func markActCompleted(_ act: Int) {
        if act > highestActCompleted {
            highestActCompleted = act
            persistToFile()
            print("ProgressStore: Ato \(act) completado! Desbloqueado próximo.")
        }
    }

    /// True se o ato dado pode ser jogado (já desbloqueado).
    func isActUnlocked(_ act: Int) -> Bool {
        act <= highestActCompleted + 1
    }

    /// Registra escolha terminal de um ato. Persistente entre runs.
    func recordTerminalChoice(_ choice: TerminalChoice) {
        switch choice.act {
        case 1: consequences.act1 = choice
        case 2: consequences.act2 = choice
        case 3: consequences.act3 = choice
        default: break
        }
        persistToFile()
        print("ProgressStore: escolha terminal Ato \(choice.act) = \(choice.rawValue)")
    }

    // MARK: - Legado

    /// @deprecated — Usado pelo menu linear.
    func markCompleted(_ operation: SalvageCore.Operation) {
        progress.markCompleted(operation)
        persistToFile()
    }

    /// Reseta TUDO. Use com cuidado.
    func reset() {
        progress.reset()
        highestActCompleted = 0
        consequences = ActConsequences()
        metaState = .empty
        persistToFile()
        print("ProgressStore: progresso resetado (tudo)")
    }

    // MARK: - Meta layer trackers (Ato 3 secret ending)

    /// Chamado quando player abre um diálogo com Henry.
    func recordHenryEncounter() {
        metaState.henryEncounters += 1
        persistToFile()
        print("META: Henry encounter #\(metaState.henryEncounters)")
    }

    /// Chamado quando player joga uma carta ghost em combate.
    func recordGhostCardPlayed() {
        metaState.ghostCardsPlayed += 1
        persistToFile()
    }

    /// Chamado no fim da run Ato 3 (após terminal choice) pra registrar quantas
    /// ghost cards estavam no deck. EndingCalculator usa pra checar Espelho.
    func recordFinalGhostCardCount(_ count: Int) {
        metaState.lastRunGhostCardCount = count
        persistToFile()
        print("META: registrado \(count) ghost cards na última run")
    }

    // MARK: - Debug helpers (long-press no version label ativa)

    /// Destrava todos os atos sem simular escolhas — pra testar Ato II/III direto.
    func debugUnlockAllActs() {
        highestActCompleted = max(highestActCompleted, 2)
        persistToFile()
        print("DEBUG: todos os atos desbloqueados")
    }

    /// Simula escolhas terminais em todos os 3 atos empurrando pra um path
    /// específico. Útil pra testar cálculos de ending.
    func debugSimulateAllChoices(path: EndingPath) {
        let (a1, a2, a3): (TerminalChoice, TerminalChoice, TerminalChoice)
        switch path {
        case .complice:
            (a1, a2, a3) = (.reportContact, .recordAtoll, .salvageArchive)
        case .contentor:
            (a1, a2, a3) = (.silenceIncident, .buryWithUnit, .burnEverything)
        case .testemunha:
            (a1, a2, a3) = (.doubtEverything, .keepSymbol, .walkAway)
        case .fugitivo, .espelho:
            // Fugitivo tem trigger próprio, Espelho é secret
            (a1, a2, a3) = (.doubtEverything, .keepSymbol, .walkAway)
        }
        consequences = ActConsequences(act1: a1, act2: a2, act3: a3)
        highestActCompleted = 3
        persistToFile()
        print("DEBUG: escolhas simuladas pra path \(path.rawValue)")
    }

    /// Simula path Fugitivo especificamente (Testemunha nos 3 atos + walkAway final).
    /// Fugitivo requer walkAway no Ato 3 + 2+ Testemunhas.
    func debugSimulateFugitivoPath() {
        consequences = ActConsequences(
            act1: .doubtEverything,
            act2: .keepSymbol,
            act3: .walkAway
        )
        highestActCompleted = 3
        persistToFile()
        print("DEBUG: path Fugitivo preparado")
    }

    /// Simula path O Espelho (ending secreto).
    /// Requer: walkAway Ato 3 + Henry encontrado + 3 ghost cards no deck da última run.
    func debugSimulateEspelhoPath() {
        consequences = ActConsequences(
            act1: .doubtEverything,
            act2: .keepSymbol,
            act3: .walkAway
        )
        metaState.henryEncounters = max(metaState.henryEncounters, 1)
        metaState.lastRunGhostCardCount = 3
        highestActCompleted = 3
        persistToFile()
        print("DEBUG: path O Espelho preparado (Henry + 3 ghost cards + walkAway)")
    }

    // MARK: - Persistence

    private struct SavePayload: Codable {
        let progress: PlayerProgress
        let highestActCompleted: Int
        let consequences: ActConsequences
        // Opcional pra backward compat com saves antigos
        let metaState: MetaLayerState?
    }

    private func persistToFile() {
        let payload = SavePayload(
            progress: progress,
            highestActCompleted: highestActCompleted,
            consequences: consequences,
            metaState: metaState
        )
        do {
            try FileStorage.save(payload, to: Self.filename)
        } catch {
            print("ProgressStore: erro persistindo — \(error)")
        }
    }
}

// MARK: - MetaLayerState (condições ocultas pro Espelho)

/// Estado meta-persistente entre runs pra destravar o ending secreto "O Espelho".
///
/// Condições registradas aqui:
/// - `henryEncounters`: quantas vezes o player conversou com Henry (todas runs)
/// - `ghostCardsPlayed`: quantas ghost cards H. o player jogou em combate (todas runs)
/// - `lastRunGhostCardCount`: quantas ghost cards estavam no deck na última run finalizada do Ato 3
struct MetaLayerState: Codable, Equatable, MetaLayerConditions {
    var henryEncounters: Int = 0
    var ghostCardsPlayed: Int = 0
    var lastRunGhostCardCount: Int = 0

    /// True se player conversou com Henry pelo menos 1 vez.
    var didMeetHenry: Bool { henryEncounters > 0 }

    /// True se player teve pelo menos 3 ghost cards no deck na última run Ato 3.
    var hadAllGhostCards: Bool { lastRunGhostCardCount >= 3 }

    static let empty = MetaLayerState()
}
