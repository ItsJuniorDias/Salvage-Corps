import Foundation

/// O motor do combate. Função pura `apply(action, state) -> newState`.
///
/// Regras do design:
/// 1. NUNCA muta o state recebido. Sempre retorna cópia modificada.
/// 2. NUNCA tem side effects (I/O, print, network).
/// 3. NUNCA usa random fora do `state.rng` (mantém determinismo).
/// 4. NUNCA depende de UIKit/SwiftUI/Foundation-Data-nonsense.
///
/// Se você quebrar qualquer uma dessas regras, os testes não vão pegar bugs
/// sutis e a UI vai começar a se comportar de forma imprevisível. Não faça.
public enum GameEngine {

    // ----------------------------------------------------------------------
    // Entry point
    // ----------------------------------------------------------------------

    public static func apply(_ action: GameAction, to state: GameState) -> ActionResult {
        var s = state
        s.events = []  // limpa eventos da action anterior

        switch action {
        case .startCombat:
            return applyStartCombat(&s)
        case .playCard(let handIndex, let targetEnemyID, let targetHandIndex):
            return applyPlayCard(&s,
                                 handIndex: handIndex,
                                 targetEnemyID: targetEnemyID,
                                 targetHandIndex: targetHandIndex)
        case .endTurn:
            return applyEndTurn(&s)
        }
    }

    // ----------------------------------------------------------------------
    // Start Combat
    // ----------------------------------------------------------------------

    private static func applyStartCombat(_ s: inout GameState) -> ActionResult {
        guard s.phase == .notStarted else {
            return .invalid(reason: .combatAlreadyStarted)
        }

        s.rng.shuffle(&s.drawPile)
        s.phase = .playerTurn
        s.turn = 1
        s.events.append(.combatStarted)
        s.events.append(.turnStarted(turn: 1))

        beginPlayerTurn(&s)
        return .applied(s)
    }

    // ----------------------------------------------------------------------
    // Player Turn Begin (helper — usado por startCombat e endTurn)
    // ----------------------------------------------------------------------

    private static func beginPlayerTurn(_ s: inout GameState) {
        // Reset energia e block
        s.player.energy = s.player.maxEnergy
        s.player.block = 0

        // Reset fog of war — intents ficam ocultas novamente (se hidden by default)
        for i in s.enemies.indices {
            s.enemies[i].intentRevealedThisTurn = false
        }

        // Corrupção (Ato 2+): perde moral igual aos stacks
        if s.corruptionEnabled {
            let stacks = s.player.statusEffects[.corruption] ?? 0
            if stacks > 0 {
                let before = s.player.moral
                s.player.moral = max(0, s.player.moral - stacks)
                let delta = s.player.moral - before  // negativo
                s.events.append(.moralChanged(delta: delta))
            }
        }

        // Compra até 5 cartas (mantém retained cards)
        let cardsToDrawTarget = 5
        let retained = s.hand  // cartas com retain=true já foram filtradas no endTurn
        let cardsToDraw = max(0, cardsToDrawTarget - retained.count)
        drawCards(&s, count: cardsToDraw)
    }

    // ----------------------------------------------------------------------
    // Play Card
    // ----------------------------------------------------------------------

    private static func applyPlayCard(
        _ s: inout GameState,
        handIndex: Int,
        targetEnemyID: UUID?,
        targetHandIndex: Int?
    ) -> ActionResult {
        guard s.phase == .playerTurn else {
            return .invalid(reason: .notPlayerTurn)
        }
        guard handIndex >= 0 && handIndex < s.hand.count else {
            return .invalid(reason: .invalidHandIndex)
        }

        let card = s.hand[handIndex]

        guard s.player.energy >= card.cost else {
            return .invalid(reason: .notEnoughEnergy)
        }

        // Validação de target
        switch card.targeting {
        case .none:
            break
        case .singleEnemy:
            guard let targetID = targetEnemyID else {
                return .invalid(reason: .targetRequired)
            }
            guard let target = s.enemies.first(where: { $0.id == targetID }),
                  target.isAlive else {
                return .invalid(reason: .invalidTarget)
            }
        case .cardInHand:
            guard let idx = targetHandIndex else {
                return .invalid(reason: .targetRequired)
            }
            // Não pode escolher a própria carta como alvo
            guard idx >= 0 && idx < s.hand.count && idx != handIndex else {
                return .invalid(reason: .invalidTarget)
            }
        }

        // Se chegou aqui, é válida. Paga custo e remove da mão.
        s.player.energy -= card.cost
        let removedCard = s.hand.remove(at: handIndex)
        s.events.append(.cardPlayed(cardID: removedCard.id, cardName: removedCard.name))

        // Corrupção (Ato 2+): corrupção acumula em cartas .corrupcao, decrementa em .resolucao
        if s.corruptionEnabled {
            switch removedCard.type {
            case .corrupcao:
                let current = s.player.statusEffects[.corruption] ?? 0
                s.player.statusEffects[.corruption] = current + 1
                s.events.append(.statusApplied(targetID: nil, status: .corruption, stacks: 1))
            case .resolucao:
                let current = s.player.statusEffects[.corruption] ?? 0
                if current > 0 {
                    let newValue = current - 1
                    if newValue <= 0 {
                        s.player.statusEffects.removeValue(forKey: .corruption)
                    } else {
                        s.player.statusEffects[.corruption] = newValue
                    }
                }
            default:
                break
            }
        }

        // Aplica cada efeito na ordem.
        // Nota: targetHandIndex pode mudar se removemos a carta jogada primeiro.
        // Como já removemos, o índice do target ainda é válido SE for menor que handIndex.
        // Se for maior, precisamos decrementar. Para simplificar, ajustamos aqui:
        var adjustedTargetHandIndex = targetHandIndex
        if let idx = targetHandIndex, idx > handIndex {
            adjustedTargetHandIndex = idx - 1
        }

        for effect in card.effects {
            applyEffect(effect,
                        to: &s,
                        targetEnemyID: targetEnemyID,
                        targetHandIndex: adjustedTargetHandIndex)
        }

        // Coloca a carta no destino apropriado
        if removedCard.exhaustAfterPlay {
            s.exhaustPile.append(removedCard)
            s.events.append(.cardExhausted(cardID: removedCard.id))
        } else {
            s.discardPile.append(removedCard)
            s.events.append(.cardDiscarded(cardID: removedCard.id))
        }

        // Checa condições de fim de combate
        checkCombatEnd(&s)

        return .applied(s)
    }

    // ----------------------------------------------------------------------
    // End Turn
    // ----------------------------------------------------------------------

    private static func applyEndTurn(_ s: inout GameState) -> ActionResult {
        guard s.phase == .playerTurn else {
            return .invalid(reason: .notPlayerTurn)
        }

        s.events.append(.turnEnded)

        // Descarta cartas não retidas
        let retained = s.hand.filter { $0.retain }
        let discarded = s.hand.filter { !$0.retain }
        for card in discarded {
            s.events.append(.cardDiscarded(cardID: card.id))
        }
        s.discardPile.append(contentsOf: discarded)
        s.hand = retained

        // Executa turno dos inimigos
        s.phase = .enemyTurn
        executeEnemyTurn(&s)
        if s.isCombatOver { return .applied(s) }

        // Volta pro turno do jogador
        s.turn += 1
        s.phase = .playerTurn
        s.events.append(.turnStarted(turn: s.turn))
        decayPlayerStatusEffects(&s)
        beginPlayerTurn(&s)

        checkCombatEnd(&s)
        return .applied(s)
    }

    // ----------------------------------------------------------------------
    // Enemy Turn Execution
    // ----------------------------------------------------------------------

    private static func executeEnemyTurn(_ s: inout GameState) {
        for i in s.enemies.indices where s.enemies[i].isAlive {
            let intent = s.enemies[i].currentIntent
            executeIntent(intent, enemyIndex: i, state: &s)

            // Skip só afeta UM turno — reseta depois
            s.enemies[i].skipNextTurn = false
            s.enemies[i].turnsCompleted += 1

            // Decay de status effects do inimigo (Medo -1 por turno, etc)
            decayEnemyStatusEffects(&s, enemyIndex: i)

            // Se jogador morreu durante o turno, para tudo
            if s.player.isDefeated { return }
        }
    }

    private static func executeIntent(_ intent: EnemyIntent, enemyIndex: Int, state s: inout GameState) {
        let enemyID = s.enemies[enemyIndex].id

        // Aplica efeito de Medo: reduz dano dos ataques
        let fearStacks = s.enemies[enemyIndex].statusEffects[.fear] ?? 0

        switch intent {
        case .attack(let damage):
            let effectiveDamage = max(0, damage - fearStacks)
            damagePlayer(&s, amount: effectiveDamage)
        case .multiAttack(let damage, let hits):
            let effectiveDamage = max(0, damage - fearStacks)
            for _ in 0..<hits {
                damagePlayer(&s, amount: effectiveDamage)
                if s.player.isDefeated { break }
            }
        case .defend(let block):
            // Inimigos podem ter block também. Adicionamos como status.
            addStatus(to: &s.enemies[enemyIndex], status: .block, stacks: block)
            s.events.append(.statusApplied(targetID: enemyID, status: .block, stacks: block))
        case .moralAttack(let damage):
            damagePlayerMoral(&s, amount: damage)
        case .attackAndMoral(let damage, let moralDamage):
            let effectiveDamage = max(0, damage - fearStacks)
            damagePlayer(&s, amount: effectiveDamage)
            if !s.player.isDefeated {
                damagePlayerMoral(&s, amount: moralDamage)
            }
        case .summon:
            // MVP: não implementado
            break
        case .skip:
            break
        }

        s.events.append(.enemyIntentExecuted(enemyID: enemyID, intent: intent))
    }

    // ----------------------------------------------------------------------
    // Effects — aplicação de cada tipo de CardEffect
    // ----------------------------------------------------------------------

    private static func applyEffect(
        _ effect: CardEffect,
        to s: inout GameState,
        targetEnemyID: UUID?,
        targetHandIndex: Int?
    ) {
        switch effect {
        case .damage(let amount):
            guard let targetID = targetEnemyID,
                  let idx = s.enemies.firstIndex(where: { $0.id == targetID }) else {
                return
            }
            damageEnemy(&s, enemyIndex: idx, amount: amount)

        case .damageAll(let amount):
            for i in s.enemies.indices where s.enemies[i].isAlive {
                damageEnemy(&s, enemyIndex: i, amount: amount)
            }
            s.events.append(.damageDealtAll(amount: amount))

        case .damageSelfMoral(let amount):
            damagePlayerMoral(&s, amount: amount)

        case .gainBlock(let amount):
            s.player.block += amount
            s.events.append(.blockGained(amount: amount))

        case .gainMoral(let amount):
            let before = s.player.moral
            s.player.moral = min(s.player.moral + amount, s.player.maxMoral)
            let delta = s.player.moral - before
            s.events.append(.moralChanged(delta: delta))

        case .applyStatus(let status, let stacks):
            guard let targetID = targetEnemyID,
                  let idx = s.enemies.firstIndex(where: { $0.id == targetID }) else {
                return
            }
            addStatus(to: &s.enemies[idx], status: status, stacks: stacks)
            s.events.append(.statusApplied(targetID: targetID, status: status, stacks: stacks))

        case .applyStatusAll(let status, let stacks):
            for i in s.enemies.indices where s.enemies[i].isAlive {
                addStatus(to: &s.enemies[i], status: status, stacks: stacks)
                s.events.append(.statusApplied(targetID: s.enemies[i].id, status: status, stacks: stacks))
            }

        case .exhaustFromHand(let handIndex):
            guard handIndex >= 0 && handIndex < s.hand.count else { return }
            let card = s.hand.remove(at: handIndex)
            s.exhaustPile.append(card)
            s.events.append(.cardExhausted(cardID: card.id))

        case .exhaustChosenFromHand:
            guard let idx = targetHandIndex,
                  idx >= 0 && idx < s.hand.count else { return }
            let card = s.hand.remove(at: idx)
            s.exhaustPile.append(card)
            s.events.append(.cardExhausted(cardID: card.id))

        case .draw(let count):
            drawCards(&s, count: count)

        case .skipNextTurn:
            guard let targetID = targetEnemyID,
                  let idx = s.enemies.firstIndex(where: { $0.id == targetID }) else {
                return
            }
            s.enemies[idx].skipNextTurn = true

        case .revealAllIntents:
            // Marca todos os enemies vivos como intent-revealed neste turno.
            // Reset acontece no beginPlayerTurn.
            for i in s.enemies.indices where s.enemies[i].isAlive {
                s.enemies[i].intentRevealedThisTurn = true
            }
        }
    }

    // ----------------------------------------------------------------------
    // Damage & healing helpers
    // ----------------------------------------------------------------------

    private static func damageEnemy(_ s: inout GameState, enemyIndex: Int, amount: Int) {
        guard s.enemies[enemyIndex].isAlive else { return }

        // Enemies também têm Block (armazenado como status effect)
        let enemyBlock = s.enemies[enemyIndex].statusEffects[.block] ?? 0
        let blocked = min(enemyBlock, amount)
        let dealt = amount - blocked

        s.enemies[enemyIndex].statusEffects[.block] = max(0, enemyBlock - blocked)
        s.enemies[enemyIndex].hp = max(0, s.enemies[enemyIndex].hp - dealt)

        s.events.append(.damageDealt(
            targetID: s.enemies[enemyIndex].id,
            amount: dealt,
            blocked: blocked
        ))

        if !s.enemies[enemyIndex].isAlive {
            s.events.append(.enemyDefeated(enemyID: s.enemies[enemyIndex].id))
        } else if let transition = s.enemies[enemyIndex].checkPhaseTransition() {
            // Boss entrou em nova fase
            s.events.append(.bossPhaseChanged(
                enemyID: s.enemies[enemyIndex].id,
                newPhase: transition.newPhase,
                intro: transition.intro
            ))
        }
    }

    private static func damagePlayer(_ s: inout GameState, amount: Int) {
        let blocked = min(s.player.block, amount)
        let dealt = amount - blocked
        s.player.block -= blocked
        let before = s.player.hp
        s.player.hp = max(0, s.player.hp - dealt)
        let delta = s.player.hp - before
        s.events.append(.playerHPChanged(delta: delta))
    }

    private static func damagePlayerMoral(_ s: inout GameState, amount: Int) {
        // Dano moral ignora block físico
        let before = s.player.moral
        s.player.moral = max(0, s.player.moral - amount)
        let delta = s.player.moral - before
        s.events.append(.moralChanged(delta: delta))
    }

    // ----------------------------------------------------------------------
    // Deck management
    // ----------------------------------------------------------------------

    private static func drawCards(_ s: inout GameState, count: Int) {
        var drawn = 0
        for _ in 0..<count {
            if s.drawPile.isEmpty && !s.discardPile.isEmpty {
                // Embaralha descarte pra formar novo deck
                s.drawPile = s.discardPile
                s.discardPile = []
                s.rng.shuffle(&s.drawPile)
                s.events.append(.deckShuffled)
            }
            if s.drawPile.isEmpty { break }
            let card = s.drawPile.removeLast()
            s.hand.append(card)
            drawn += 1
        }
        if drawn > 0 {
            s.events.append(.cardsDrawn(count: drawn))
        }
    }

    // ----------------------------------------------------------------------
    // Status effects
    // ----------------------------------------------------------------------

    private static func addStatus(to enemy: inout Enemy, status: StatusEffect, stacks: Int) {
        enemy.statusEffects[status, default: 0] += stacks
    }

    private static func decayEnemyStatusEffects(_ s: inout GameState, enemyIndex: Int) {
        // Fear diminui 1 por turno
        if var fear = s.enemies[enemyIndex].statusEffects[.fear], fear > 0 {
            fear -= 1
            if fear <= 0 {
                s.enemies[enemyIndex].statusEffects.removeValue(forKey: .fear)
            } else {
                s.enemies[enemyIndex].statusEffects[.fear] = fear
            }
        }
    }

    private static func decayPlayerStatusEffects(_ s: inout GameState) {
        // Block do jogador zera no início do turno dele (já feito em beginPlayerTurn)
        // Espaço reservado pra outros decays futuros
    }

    // ----------------------------------------------------------------------
    // Combat end detection
    // ----------------------------------------------------------------------

    private static func checkCombatEnd(_ s: inout GameState) {
        if s.livingEnemies.isEmpty {
            s.phase = .victory
            s.events.append(.combatWon)
            return
        }
        if s.player.isDefeated {
            let reason = s.player.defeatReason ?? .hp
            s.phase = .defeat(reason: reason)
            s.events.append(.combatLost(reason: reason))
        }
    }
}
