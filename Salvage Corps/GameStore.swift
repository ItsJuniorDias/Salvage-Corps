import Foundation
import SwiftUI
import SalvageCore

/// Wrapper Observable do GameState pra SwiftUI.
///
/// Responsabilidades:
/// - Segurar o state atual
/// - Expor dispatch(action) que roda o reducer e publica novo state
/// - Guardar histórico pra undo (opcional, útil pra debug)
///
/// Não coloca lógica de jogo aqui. NUNCA. Tudo passa pelo GameEngine.
@Observable
final class GameStore {

    private(set) var state: GameState
    private var history: [GameState] = []

    /// Ative pra logar todas actions no console (útil quando algo esquisito acontece).
    var debugLogging: Bool = true

    /// Ative pra manter histórico de states pra undo. Cuidado com memória.
    var enableUndo: Bool = false

    init(state: GameState) {
        self.state = state
    }

    // ----------------------------------------------------------------------
    // Convenience factories
    // ----------------------------------------------------------------------

    static func newCombat(
        enemies: [Enemy] = StarterEnemies.encounterEasy(),
        seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> GameStore {
        let state = GameState(
            player: PlayerState(),
            enemies: enemies,
            deck: StarterDeck.edmundStartingDeck(),
            seed: seed
        )
        let store = GameStore(state: state)
        store.dispatch(.startCombat)
        return store
    }

    /// Cria combate com HP/Moral iniciais específicos (vindos do RunPlayerState).
    /// Usado quando o player já tá com HP/Moral reduzidos de combates anteriores.
    /// Opcionalmente aplica upgrades do PlayerDeck na construção do deck.
    static func newCombat(
        enemies: [Enemy],
        currentHP: Int,
        maxHP: Int,
        currentMoral: Int,
        maxMoral: Int,
        playerDeck: PlayerDeck = PlayerDeck(),
        corruptionEnabled: Bool = false,
        seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) -> GameStore {
        let state = GameState(
            player: PlayerState(
                currentHP: currentHP,
                maxHP: maxHP,
                currentMoral: currentMoral,
                maxMoral: maxMoral
            ),
            enemies: enemies,
            deck: StarterDeck.buildDeck(with: playerDeck),
            seed: seed,
            corruptionEnabled: corruptionEnabled
        )
        let store = GameStore(state: state)
        store.dispatch(.startCombat)
        return store
    }

    // ----------------------------------------------------------------------
    // Dispatch
    // ----------------------------------------------------------------------

    /// Aplica uma ação. Se inválida, apenas loga (não crash).
    /// Retorna true se aplicou com sucesso.
    @discardableResult
    func dispatch(_ action: GameAction) -> Bool {
        if debugLogging {
            print("→ dispatch: \(action)")
        }

        let result = GameEngine.apply(action, to: state)

        switch result {
        case .applied(let newState):
            if enableUndo { history.append(state) }
            state = newState
            if debugLogging {
                for event in newState.events {
                    print("  · \(event)")
                }
            }
            return true

        case .invalid(let error):
            if debugLogging {
                print("  ✗ INVALID: \(error)")
            }
            return false
        }
    }

    // ----------------------------------------------------------------------
    // Undo (opcional)
    // ----------------------------------------------------------------------

    func undo() {
        guard let previous = history.popLast() else { return }
        state = previous
    }

    var canUndo: Bool { !history.isEmpty }
}
