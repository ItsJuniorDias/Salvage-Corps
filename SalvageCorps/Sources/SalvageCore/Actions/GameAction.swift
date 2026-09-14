import Foundation

/// Todas as ações possíveis que mudam o estado do combate.
///
/// Cada input do jogador (clicar carta, terminar turno) vira uma ação aqui.
/// O `GameEngine.apply(action, to: state)` é a ÚNICA função que muta estado.
/// Tudo mais é derivação.
///
/// Benefícios:
/// - Replay: gravar ações + seed inicial reproduz qualquer sessão
/// - Undo: manter stack de estados anteriores é trivial
/// - Test: testar cada action em isolamento
/// - Debug: logar todas ações pra investigar bugs
public enum GameAction: Equatable, Codable {

    /// Inicia o combate. Deve ser a primeira action.
    case startCombat

    /// Joga uma carta da mão.
    /// - handIndex: posição da carta na mão (0..<hand.count)
    /// - targetEnemyID: ID do inimigo alvo. Obrigatório se carta requer .singleEnemy.
    /// - targetHandIndex: posição da carta alvo na mão. Obrigatório se .cardInHand.
    case playCard(
        handIndex: Int,
        targetEnemyID: UUID? = nil,
        targetHandIndex: Int? = nil
    )

    /// Encerra o turno do jogador. Descarta mão, executa inimigos, saca 5 novas.
    case endTurn
}


/// Resultado de tentar aplicar uma ação. Se falhou, contém o motivo.
public enum ActionResult: Equatable {
    case applied(GameState)
    case invalid(reason: ActionError)
}


public enum ActionError: String, Equatable, Error {
    case combatNotActive
    case notPlayerTurn
    case invalidHandIndex
    case notEnoughEnergy
    case targetRequired
    case invalidTarget
    case cardHasNoValidTarget
    case combatAlreadyStarted
}
