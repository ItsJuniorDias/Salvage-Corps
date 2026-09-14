//
//  LeaderboardPresentDelegate.swift
//  Salvage Corps
//
//  Fase 9: delegate singleton pro GKGameCenterViewController do leaderboard
//  de rating. Só serve pra dismissar o VC quando o user fecha.
//

import Foundation
import GameKit

final class LeaderboardPresentDelegate: NSObject, GKGameCenterControllerDelegate {

    static let shared = LeaderboardPresentDelegate()

    private override init() { super.init() }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
