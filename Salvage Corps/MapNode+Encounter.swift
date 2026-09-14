//
//  MapNode+Encounter.swift
//  Salvage Corps
//
//  Deriva um encounter (lista de inimigos) a partir de um MapNode + ato.
//  Determinístico: mesmo UUID + ato = mesmo encounter (permite retomar save
//  sem trocar composição do combate).
//

import Foundation
import SalvageCore

extension MapNode {

    /// Constrói o encounter correspondente a este nó pra um ato específico.
    /// Seed derivada do UUID pra ser reproduzível entre re-abertas do app.
    func makeEncounter(act: Int) -> [Enemy] {
        // Hash do UUID pra seed determinística e estável
        let seed = UInt64(bitPattern: Int64(self.id.hashValue))
        var rng = SeededRandom(seed: seed)

        switch (kind, act) {

        // MARK: - Ato 1
        case (.combat, 1):
            // 65% easy, 35% medium
            let roll = rng.int(in: 0...99)
            return roll < 65
                ? StarterEnemies.encounterEasy()
                : StarterEnemies.encounterMedium()

        case (.elite, 1):
            return StarterEnemies.encounterHard()

        case (.boss, 1):
            return StarterEnemies.encounterBoss()

        // MARK: - Ato 2
        case (.combat, 2):
            let roll = rng.int(in: 0...99)
            return roll < 60
                ? StarterEnemies.act2EncounterEasy()
                : StarterEnemies.act2EncounterMedium()

        case (.elite, 2):
            return StarterEnemies.act2EncounterHard()

        case (.boss, 2):
            return StarterEnemies.act2EncounterBoss()

        // MARK: - Ato 3
        case (.combat, 3):
            // Rebalance: 55% → 70% easy. Ato 3 estava punindo demais em runs
            // médias — a diferença entre Easy (1 whisper após nerf) e Medium
            // (granadeiro + whisper) é grande e o player já entra machucado.
            let roll = rng.int(in: 0...99)
            return roll < 70
                ? StarterEnemies.act3EncounterEasy()
                : StarterEnemies.act3EncounterMedium()

        case (.elite, 3):
            return StarterEnemies.act3EncounterHard()

        case (.boss, 3):
            return StarterEnemies.act3EncounterBoss()

        // Nós não-combate ou ato desconhecido
        default:
            return []
        }
    }

    /// Versão legada — usa ato 1 por padrão (compat com callers antigos).
    func makeEncounter() -> [Enemy] {
        makeEncounter(act: 1)
    }
}
