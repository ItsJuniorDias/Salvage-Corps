import Foundation

/// Motor do duelo PvP. Função pura `apply(action, state) -> newState`.
///
/// Segue as mesmas 4 regras do `GameEngine` do single-player:
/// 1. NUNCA muta o state recebido. Sempre retorna cópia modificada.
/// 2. NUNCA tem side effects (I/O, print, network).
/// 3. NUNCA usa random fora dos `rng` dos players (mantém determinismo).
/// 4. NUNCA depende de UIKit/SwiftUI/Foundation-Data-nonsense.
///
/// **Convenções de tradução single-player → duelo:**
///
/// | CardEffect                | Comportamento no duelo                     |
/// |---------------------------|--------------------------------------------|
/// | `.damage(N)`              | Dano no OPONENTE (target implícito)        |
/// | `.damageAll(N)`           | Dano no OPONENTE (só existe 1 "inimigo")   |
/// | `.damageSelfMoral(N)`     | Auto-dano moral no player que jogou        |
/// | `.gainBlock(N)`           | Block pro player que jogou                 |
/// | `.gainMoral(N)`           | Moral pro player que jogou                 |
/// | `.applyStatus(fear, N)`   | Fear no OPONENTE                           |
/// | `.applyStatusAll(...)`    | Idem — só existe 1 alvo                    |
/// | `.exhaustFromHand(idx)`   | Exila da própria mão                       |
/// | `.exhaustChosenFromHand`  | Exila carta escolhida da própria mão       |
/// | `.draw(N)`                | Draw do próprio deck                       |
/// | `.skipNextTurn`           | Marca skip no próximo turno do OPONENTE    |
/// | `.revealAllIntents`       | NO-OP (duelo não tem intents ocultas)      |
public enum DuelEngine {

    // ------------------------------------------------------------------
    // Entry point
    // ------------------------------------------------------------------

    public static func apply(_ action: DuelAction, to state: DuelState) -> DuelActionResult {
        var s = state
        // NÃO limpa events automaticamente — events acumula durante o turno.
        // Cada handler decide se limpa (startDuel limpa; playCard acumula;
        // endTurn preserva em previousTurnEvents antes de limpar; forfeit limpa).

        switch action {
        case .startDuel:
            return applyStartDuel(&s)
        case .submitOpponentDeck(let pid, let deck):
            return applySubmitOpponentDeck(&s, playerID: pid, deck: deck)
        case .playCard(let pid, let handIndex, let targetHandIndex):
            return applyPlayCard(&s, playerID: pid, handIndex: handIndex, targetHandIndex: targetHandIndex)
        case .endTurn(let pid):
            return applyEndTurn(&s, playerID: pid)
        case .forfeit(let pid):
            return applyForfeit(&s, playerID: pid)
        }
    }

    // ------------------------------------------------------------------
    // Start Duel
    // ------------------------------------------------------------------

    private static func applyStartDuel(_ s: inout DuelState) -> DuelActionResult {
        guard s.phase == .notStarted else {
            return .invalid(reason: .duelAlreadyStarted)
        }

        // Fresh start — apaga qualquer resíduo hipotético
        s.events = []
        s.previousTurnEvents = []

        // Embaralha os dois decks com RNGs isolados.
        s.playerA.rng.shuffle(&s.playerA.drawPile)
        s.playerB.rng.shuffle(&s.playerB.drawPile)

        // Ambos os players sacam mão inicial de 5. Só o active ganha energia
        // agora — waiting player recebe energia quando o turno dele começar
        // (via beginPlayerTurn no handoff dentro de applyEndTurn).
        drawCards(&s, playerID: s.playerA.playerID, count: 5)
        drawCards(&s, playerID: s.playerB.playerID, count: 5)

        s.phase = .active
        s.turn = 1
        s.events.append(.duelStarted)
        s.events.append(.turnStarted(playerID: s.activePlayerID, turn: 1))

        // Só o active player tem beginPlayerTurn agora — reseta energia/block
        // dele e faz decay de fear. Os draws já aconteceram acima pra ambos.
        // (beginPlayerTurn também tenta draw até 5, mas hand já tá com 5 → no-op.)
        beginPlayerTurn(&s, playerID: s.activePlayerID)
        return .applied(s)
    }

    // ------------------------------------------------------------------
    // Submit Opponent Deck (fluxo PvP: deck customizado)
    // ------------------------------------------------------------------

    /// Fluxo: host cria state em `.awaitingOpponentDeck` com seu próprio deck em
    /// `playerA.drawPile` e `playerB.drawPile` vazio. `activePlayerID` = oponente.
    /// Oponente abre match, submete seu deck via essa action. Engine preenche
    /// `playerB.drawPile`, invoca `applyStartDuel` internamente (embaralha ambos,
    /// saca mãos), muda phase pra `.active` e devolve a vez pro `firstToPlay`
    /// original (via metadado guardado no state — ver DuelFactory).
    private static func applySubmitOpponentDeck(
        _ s: inout DuelState,
        playerID: String,
        deck: [Card]
    ) -> DuelActionResult {
        guard s.phase == .awaitingOpponentDeck else {
            return .invalid(reason: .notInDeckSubmissionPhase)
        }
        guard s.player(withID: playerID) != nil else {
            return .invalid(reason: .unknownPlayer)
        }
        guard playerID == s.activePlayerID else {
            // Só o não-host (o activePlayerID nessa fase) pode submeter.
            return .invalid(reason: .hostCantSubmitOpponentDeck)
        }
        guard !deck.isEmpty else {
            return .invalid(reason: .deckEmpty)
        }
        // Engine confia no size (DuelDeckConfig.validate() é responsabilidade da UI).
        // Aqui só valida > 0 pra evitar draw pile permanentemente vazia.

        // Preenche o drawPile do submetente
        modifyPlayer(&s, id: playerID) { p in
            p.drawPile = deck
        }

        // Transiciona pra .notStarted pra applyStartDuel aceitar
        s.phase = .notStarted

        // Devolve a vez pro firstToPlay original (guardado em firstToPlayID pelo Factory).
        // Em .awaitingOpponentDeck, activePlayerID era o oponente do host — agora vira o host.
        if let firstPlay = s.firstToPlayID {
            s.activePlayerID = firstPlay
        }
        // Se firstToPlayID for nil (state criado manualmente sem Factory), mantém
        // o activePlayerID atual — não ideal mas seguro.

        // Dispara startDuel — embaralha, saca mãos, phase = .active
        return applyStartDuel(&s)
    }

    // ------------------------------------------------------------------
    // Begin Player Turn (helper)
    // ------------------------------------------------------------------

    /// Chamado no início do turno de um player (após startDuel ou após handoff).
    /// - Reseta energia e block do player
    /// - Faz decay de fear (Slay-style: 1 stack a cada início de turno do afetado)
    /// - Compra até 5 cartas (respeitando retained), com fadiga se pile vazio
    private static func beginPlayerTurn(_ s: inout DuelState, playerID: String) {
        modifyPlayer(&s, id: playerID) { p in
            p.player.energy = p.player.maxEnergy
            p.player.block = 0

            // Decay de fear (mesma regra do single-player)
            if var fear = p.player.statusEffects[.fear], fear > 0 {
                fear -= 1
                if fear <= 0 {
                    p.player.statusEffects.removeValue(forKey: .fear)
                } else {
                    p.player.statusEffects[.fear] = fear
                }
            }
        }

        // Compra até 5 (mantém retained cards)
        let currentHandCount = playerRef(in: s, id: playerID).hand.count
        let cardsToDraw = max(0, 5 - currentHandCount)
        drawCards(&s, playerID: playerID, count: cardsToDraw)
    }

    // ------------------------------------------------------------------
    // Play Card
    // ------------------------------------------------------------------

    private static func applyPlayCard(
        _ s: inout DuelState,
        playerID: String,
        handIndex: Int,
        targetHandIndex: Int?
    ) -> DuelActionResult {
        guard s.phase == .active else {
            return .invalid(reason: .duelNotActive)
        }
        guard playerID == s.activePlayerID else {
            return .invalid(reason: .notYourTurn)
        }
        guard s.player(withID: playerID) != nil else {
            return .invalid(reason: .unknownPlayer)
        }

        let actor = playerRef(in: s, id: playerID)
        guard handIndex >= 0 && handIndex < actor.hand.count else {
            return .invalid(reason: .invalidHandIndex)
        }

        let card = actor.hand[handIndex]
        guard actor.player.energy >= card.cost else {
            return .invalid(reason: .notEnoughEnergy)
        }

        // Validação de targeting.
        // .singleEnemy em duelo = oponente (implícito, não precisa ID).
        // .cardInHand precisa de targetHandIndex válido.
        switch card.targeting {
        case .none, .singleEnemy:
            break
        case .cardInHand:
            guard let idx = targetHandIndex else {
                return .invalid(reason: .targetRequired)
            }
            guard idx >= 0 && idx < actor.hand.count && idx != handIndex else {
                return .invalid(reason: .invalidTarget)
            }
        }

        // Válida — paga custo e remove da mão.
        modifyPlayer(&s, id: playerID) { p in
            p.player.energy -= card.cost
        }
        let removedCard = removeHandCard(&s, playerID: playerID, at: handIndex)
        s.events.append(.cardPlayed(playerID: playerID, cardID: removedCard.id, cardName: removedCard.name))

        // Ajusta targetHandIndex se a carta jogada estava antes dele.
        var adjustedTargetHandIndex = targetHandIndex
        if let idx = targetHandIndex, idx > handIndex {
            adjustedTargetHandIndex = idx - 1
        }

        // Aplica cada efeito na ordem.
        for effect in card.effects {
            applyEffect(effect, to: &s, actorID: playerID, targetHandIndex: adjustedTargetHandIndex)
        }

        // Coloca a carta em exile ou discard.
        if removedCard.exhaustAfterPlay {
            appendToExhaust(&s, playerID: playerID, card: removedCard)
            s.events.append(.cardExhausted(playerID: playerID, cardID: removedCard.id))
        } else {
            appendToDiscard(&s, playerID: playerID, card: removedCard)
            s.events.append(.cardDiscarded(playerID: playerID, cardID: removedCard.id))
        }

        checkDuelEnd(&s)
        return .applied(s)
    }

    // ------------------------------------------------------------------
    // End Turn
    // ------------------------------------------------------------------

    private static func applyEndTurn(_ s: inout DuelState, playerID: String) -> DuelActionResult {
        guard s.phase == .active else {
            return .invalid(reason: .duelNotActive)
        }
        guard playerID == s.activePlayerID else {
            return .invalid(reason: .notYourTurn)
        }
        guard let opponentID = s.opponentID(of: playerID) else {
            return .invalid(reason: .unknownPlayer)
        }

        // events atual = tudo o que aconteceu no turno do player que agora termina
        // (todas as playCards + effects). Vamos ADICIONAR o resto (turnEnded + discards
        // + handoff + beginPlayerTurn) e no final SNAPSHOT tudo pra previousTurnEvents
        // — assim o recap pro próximo player mostra o turno inteiro.

        s.events.append(.turnEnded(playerID: playerID))

        // Descarta cartas não-retidas da mão do player que terminou.
        let retained = playerRef(in: s, id: playerID).hand.filter { $0.retain }
        let discarded = playerRef(in: s, id: playerID).hand.filter { !$0.retain }
        for card in discarded {
            s.events.append(.cardDiscarded(playerID: playerID, cardID: card.id))
        }
        modifyPlayer(&s, id: playerID) { p in
            p.hand = retained
            p.discardPile.append(contentsOf: discarded)
        }

        // Handoff: passa a vez pro oponente.
        s.turn += 1
        s.activePlayerID = opponentID

        // Se o oponente estava marcado pra pular o próximo turno, resolve
        // aqui mesmo e passa a vez de volta. Consome 1 stack de skip — se
        // ainda restarem (múltiplas Empurrar Frente empilhadas), próximo
        // handoff pula de novo.
        let opponentSkipStacks = playerRef(in: s, id: opponentID).player.statusEffects[.skipNextTurn] ?? 0
        if opponentSkipStacks > 0 {
            s.events.append(.turnStarted(playerID: opponentID, turn: s.turn))
            modifyPlayer(&s, id: opponentID) { p in
                let new = opponentSkipStacks - 1
                if new <= 0 {
                    p.player.statusEffects.removeValue(forKey: .skipNextTurn)
                } else {
                    p.player.statusEffects[.skipNextTurn] = new
                }
            }
            s.events.append(.turnSkipped(playerID: opponentID))
            s.events.append(.turnEnded(playerID: opponentID))

            // Volta pro player original.
            s.turn += 1
            s.activePlayerID = playerID
            s.events.append(.turnStarted(playerID: playerID, turn: s.turn))
            beginPlayerTurn(&s, playerID: playerID)
        } else {
            s.events.append(.turnStarted(playerID: opponentID, turn: s.turn))
            beginPlayerTurn(&s, playerID: opponentID)
        }

        // Snapshot: tudo o que aconteceu neste dispatch (turno inteiro + handoff +
        // beginPlayerTurn do próximo) vira o recap pra próxima UI ler.
        // events zera pra o próximo turno começar limpo (as próximas playCards
        // acumulam do zero).
        s.previousTurnEvents = s.events
        s.events = []

        checkDuelEnd(&s)
        return .applied(s)
    }

    // ------------------------------------------------------------------
    // Forfeit
    // ------------------------------------------------------------------

    private static func applyForfeit(_ s: inout DuelState, playerID: String) -> DuelActionResult {
        guard s.phase == .active || s.phase == .notStarted else {
            return .invalid(reason: .duelNotActive)
        }
        guard s.player(withID: playerID) != nil else {
            return .invalid(reason: .unknownPlayer)
        }
        // Forfeit é ação terminal — snapshot events atual + limpa + só forfeit.
        s.previousTurnEvents = s.events + [.duelForfeit(loserID: playerID)]
        s.events = [.duelForfeit(loserID: playerID)]
        s.phase = .forfeit(loserID: playerID)
        return .applied(s)
    }

    // ------------------------------------------------------------------
    // Effects
    // ------------------------------------------------------------------

    private static func applyEffect(
        _ effect: CardEffect,
        to s: inout DuelState,
        actorID: String,
        targetHandIndex: Int?
    ) {
        guard let opponentID = s.opponentID(of: actorID) else { return }

        // Fear atrapalha ATAQUES do actor. Lê stacks do actor (quem tem fear
        // erra o alvo — é o efeito canônico).
        let actorFearStacks = playerRef(in: s, id: actorID).player.statusEffects[.fear] ?? 0

        switch effect {
        case .damage(let amount):
            let effective = max(0, amount - actorFearStacks)
            damagePlayer(&s, targetID: opponentID, amount: effective)

        case .damageAll(let amount):
            // Só existe 1 "inimigo" em duelo — o oponente.
            let effective = max(0, amount - actorFearStacks)
            damagePlayer(&s, targetID: opponentID, amount: effective)

        case .damageSelfMoral(let amount):
            damagePlayerMoral(&s, targetID: actorID, amount: amount)

        case .gainBlock(let amount):
            modifyPlayer(&s, id: actorID) { p in
                p.player.block += amount
            }
            s.events.append(.blockGained(playerID: actorID, amount: amount))

        case .gainMoral(let amount):
            var delta = 0
            modifyPlayer(&s, id: actorID) { p in
                let before = p.player.moral
                p.player.moral = min(p.player.moral + amount, p.player.maxMoral)
                delta = p.player.moral - before
            }
            if delta != 0 {
                s.events.append(.moralChanged(targetPlayerID: actorID, delta: delta))
            }

        case .applyStatus(let status, let stacks):
            // Sempre aplica no oponente (equivalente a "target enemy" no single-player).
            addStatus(&s, targetID: opponentID, status: status, stacks: stacks)
            s.events.append(.statusApplied(targetPlayerID: opponentID, status: status, stacks: stacks))

        case .applyStatusAll(let status, let stacks):
            // Só há 1 alvo em duelo — mesmo efeito que applyStatus.
            addStatus(&s, targetID: opponentID, status: status, stacks: stacks)
            s.events.append(.statusApplied(targetPlayerID: opponentID, status: status, stacks: stacks))

        case .exhaustFromHand(let handIndex):
            let hand = playerRef(in: s, id: actorID).hand
            guard handIndex >= 0 && handIndex < hand.count else { return }
            let card = removeHandCard(&s, playerID: actorID, at: handIndex)
            appendToExhaust(&s, playerID: actorID, card: card)
            s.events.append(.cardExhausted(playerID: actorID, cardID: card.id))

        case .exhaustChosenFromHand:
            guard let idx = targetHandIndex else { return }
            let hand = playerRef(in: s, id: actorID).hand
            guard idx >= 0 && idx < hand.count else { return }
            let card = removeHandCard(&s, playerID: actorID, at: idx)
            appendToExhaust(&s, playerID: actorID, card: card)
            s.events.append(.cardExhausted(playerID: actorID, cardID: card.id))

        case .draw(let count):
            drawCards(&s, playerID: actorID, count: count)

        case .skipNextTurn:
            // Marca o oponente pra pular o próximo turno dele. Usamos statusEffects
            // do PlayerState pra guardar (StatusEffect.skipNextTurn) — Codable,
            // persistido no matchData, resolvido no handoff dentro de applyEndTurn.
            addStatus(&s, targetID: opponentID, status: .skipNextTurn, stacks: 1)
            s.events.append(.skipTurnApplied(targetPlayerID: opponentID))

        case .revealAllIntents:
            // NO-OP em duelo: não existem intents ocultas (só há um player humano
            // do outro lado, sem AI com intent pattern telegrafado). Silenciosamente
            // ignorado pra manter compat com cartas do single-player.
            break
        }
    }

    // ------------------------------------------------------------------
    // Damage helpers
    // ------------------------------------------------------------------

    private static func damagePlayer(_ s: inout DuelState, targetID: String, amount: Int) {
        var blocked = 0
        var dealt = 0
        modifyPlayer(&s, id: targetID) { p in
            blocked = min(p.player.block, amount)
            dealt = amount - blocked
            p.player.block -= blocked
            p.player.hp = max(0, p.player.hp - dealt)
        }
        s.events.append(.damageDealt(targetPlayerID: targetID, amount: dealt, blocked: blocked))
        if dealt > 0 {
            s.events.append(.hpChanged(targetPlayerID: targetID, delta: -dealt))
        }
    }

    private static func damagePlayerMoral(_ s: inout DuelState, targetID: String, amount: Int) {
        var delta = 0
        modifyPlayer(&s, id: targetID) { p in
            let before = p.player.moral
            p.player.moral = max(0, p.player.moral - amount)
            delta = p.player.moral - before
        }
        if delta != 0 {
            s.events.append(.moralChanged(targetPlayerID: targetID, delta: delta))
        }
    }

    // ------------------------------------------------------------------
    // Deck helpers
    // ------------------------------------------------------------------

    private static func drawCards(_ s: inout DuelState, playerID: String, count: Int) {
        var drawn = 0
        for _ in 0..<count {
            let currentDrawEmpty = playerRef(in: s, id: playerID).drawPile.isEmpty
            let currentDiscardEmpty = playerRef(in: s, id: playerID).discardPile.isEmpty

            if currentDrawEmpty && !currentDiscardEmpty {
                // Reshuffle discard → draw
                modifyPlayer(&s, id: playerID) { p in
                    p.drawPile = p.discardPile
                    p.discardPile = []
                    p.rng.shuffle(&p.drawPile)
                }
                s.events.append(.deckShuffled(playerID: playerID))
            }

            if playerRef(in: s, id: playerID).drawPile.isEmpty {
                // Fadiga (No Man's Land): não tem mais carta pra sacar.
                // Incrementa contador e aplica dano igual ao contador atual.
                modifyPlayer(&s, id: playerID) { p in
                    p.fatigueCounter += 1
                }
                let fatigueDamage = playerRef(in: s, id: playerID).fatigueCounter
                // Fadiga IGNORA block — é dano puro.
                modifyPlayer(&s, id: playerID) { p in
                    p.player.hp = max(0, p.player.hp - fatigueDamage)
                }
                s.events.append(.fatigueDamage(playerID: playerID, amount: fatigueDamage))
                s.events.append(.hpChanged(targetPlayerID: playerID, delta: -fatigueDamage))
                continue
            }

            modifyPlayer(&s, id: playerID) { p in
                let card = p.drawPile.removeLast()  // pré-checagem acima garante
                p.hand.append(card)
            }
            drawn += 1
        }
        if drawn > 0 {
            s.events.append(.cardsDrawn(playerID: playerID, count: drawn))
        }
    }

    private static func addStatus(_ s: inout DuelState, targetID: String, status: StatusEffect, stacks: Int) {
        modifyPlayer(&s, id: targetID) { p in
            p.player.statusEffects[status, default: 0] += stacks
        }
    }

    // ------------------------------------------------------------------
    // Duel end detection
    // ------------------------------------------------------------------

    private static func checkDuelEnd(_ s: inout DuelState) {
        // Se ambos morreram no mesmo tick (ex: cartas AoE simétricas), quem
        // recebeu dano por último perde. Como damage é aplicado em ordem por
        // effect, o último modificado é o loser. Aqui, o oponente do actor
        // atual é geralmente quem toma dano — se AMBOS morreram, o actor
        // vence (ele tá jogando, oponente morreu primeiro pelo dano da carta).
        let aDefeated = s.playerA.isDefeated
        let bDefeated = s.playerB.isDefeated

        if aDefeated && bDefeated {
            // Empate raro. Vence quem NÃO tá com turno ativo (o outro tomou dano da carta jogada).
            // Convenção: se actor morreu pela própria carta (damageSelfMoral levou a 0), ele perde.
            // Nesse caso o oponente vence.
            let winner = s.opponentID(of: s.activePlayerID) ?? s.playerA.playerID
            s.phase = .victory(winnerID: winner)
            s.events.append(.duelWon(winnerID: winner))
        } else if aDefeated {
            s.phase = .victory(winnerID: s.playerB.playerID)
            s.events.append(.duelWon(winnerID: s.playerB.playerID))
        } else if bDefeated {
            s.phase = .victory(winnerID: s.playerA.playerID)
            s.events.append(.duelWon(winnerID: s.playerA.playerID))
        }
    }

    // ------------------------------------------------------------------
    // Mutation helpers — DuelState tem 2 players como campos separados
    // (playerA, playerB), não array. Estes helpers evitam duplicar código.
    // ------------------------------------------------------------------

    private static func modifyPlayer(
        _ s: inout DuelState,
        id: String,
        _ mutate: (inout DuelPlayerState) -> Void
    ) {
        if s.playerA.playerID == id {
            mutate(&s.playerA)
        } else if s.playerB.playerID == id {
            mutate(&s.playerB)
        }
    }

    private static func playerRef(in s: DuelState, id: String) -> DuelPlayerState {
        if s.playerA.playerID == id { return s.playerA }
        return s.playerB
    }

    private static func removeHandCard(_ s: inout DuelState, playerID: String, at index: Int) -> Card {
        var card: Card!
        modifyPlayer(&s, id: playerID) { p in
            card = p.hand.remove(at: index)
        }
        return card
    }

    private static func appendToDiscard(_ s: inout DuelState, playerID: String, card: Card) {
        modifyPlayer(&s, id: playerID) { p in
            p.discardPile.append(card)
        }
    }

    private static func appendToExhaust(_ s: inout DuelState, playerID: String, card: Card) {
        modifyPlayer(&s, id: playerID) { p in
            p.exhaustPile.append(card)
        }
    }
}
