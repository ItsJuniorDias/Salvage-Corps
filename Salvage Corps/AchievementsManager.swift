//
//  AchievementsManager.swift
//  Salvage Corps
//
//  Fase 11: reporta achievements pro Game Center após duelos. Chama
//  AchievementEvaluator (core, puro) pra decidir o quê, e disparar
//  via GKAchievement.report.
//

import Foundation
import GameKit
import SalvageCore

@MainActor
final class AchievementsManager {

    static let shared = AchievementsManager()

    private init() {}

    // MARK: - Evaluate + report

    /// Chamado pelo `DuelMatchStore` após aplicar delta ELO num match terminado.
    /// Pega snapshot do outcome, passa pro evaluator puro, reporta cada
    /// achievement retornado pro Game Center.
    ///
    /// Se offline ou Game Center não autenticado, os reports simplesmente
    /// falham silenciosamente — Apple oferece retry automático quando a app
    /// re-autentica (não precisamos implementar queue local).
    func evaluateAndReport(_ snapshot: DuelOutcomeSnapshot) {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("[Achievements] Não autenticado — pulando report")
            return
        }

        let results = AchievementEvaluator.evaluate(snapshot)
        guard !results.isEmpty else {
            print("[Achievements] Nada a reportar pra esse outcome")
            return
        }

        // Constrói lista de GKAchievement pra enviar em batch (mais eficiente
        // que report individual — 1 request só)
        let gkAchievements: [GKAchievement] = results.map { (ach, percent) in
            let gk = GKAchievement(identifier: ach.identifier)
            gk.percentComplete = percent * 100.0  // GK usa 0-100, não 0-1
            gk.showsCompletionBanner = true       // Apple mostra banner nativo em 100%
            return gk
        }

        print("[Achievements] Reportando \(gkAchievements.count) achievement(s):")
        for gk in gkAchievements {
            print("  · \(gk.identifier) → \(gk.percentComplete)%")
        }

        GKAchievement.report(gkAchievements) { error in
            if let error = error {
                print("[Achievements] Falha ao reportar: \(error.localizedDescription)")
            } else {
                print("[Achievements] Report enviado com sucesso")
            }
        }
    }

    // MARK: - Dev / debug

    /// Zera TODOS os achievements no Game Center do jogador atual. Só chame
    /// em contexto de desenvolvimento — sem confirmação, sem undo, e o user
    /// perde progresso permanentemente.
    func devResetAllAchievements() {
        GKAchievement.resetAchievements { error in
            if let error = error {
                print("[Achievements] Falha ao resetar: \(error.localizedDescription)")
            } else {
                print("[Achievements] DEV RESET aplicado — todos zerados")
            }
        }
    }
}
