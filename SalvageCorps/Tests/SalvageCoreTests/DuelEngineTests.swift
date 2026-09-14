import XCTest
@testable import SalvageCore

final class DuelEngineTests: XCTestCase {

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private let alice = "alice"
    private let bob = "bob"

    /// Cria duelo starter Edmund vs Edmund. Seeds fixas por default pra reproduzibilidade.
    private func makeDuel(
        first: String? = nil,
        seedA: UInt64 = 111,
        seedB: UInt64 = 222
    ) -> DuelState {
        DuelFactory.edmundVsEdmund(
            playerAID: alice,
            playerBID: bob,
            firstToPlay: first ?? alice,
            seedA: seedA,
            seedB: seedB
        )
    }

    /// Aplica `.startDuel` e retorna o novo state. Fail se falhar.
    private func started(_ state: DuelState) -> DuelState {
        guard case .applied(let s) = DuelEngine.apply(.startDuel, to: state) else {
            XCTFail("startDuel falhou")
            return state
        }
        return s
    }

    // ------------------------------------------------------------------
    // Determinismo
    // ------------------------------------------------------------------

    func test_determinism_sameSeedProducesSameShuffle() {
        let s1 = started(makeDuel(seedA: 42, seedB: 99))
        let s2 = started(makeDuel(seedA: 42, seedB: 99))
        XCTAssertEqual(s1.playerA.hand.map(\.name), s2.playerA.hand.map(\.name),
                       "Mesma seed = mesmo shuffle pra playerA")
        XCTAssertEqual(s1.playerB.hand.map(\.name), s2.playerB.hand.map(\.name),
                       "Mesma seed = mesmo shuffle pra playerB")
    }

    func test_determinism_differentSeedsProduceIsolatedShuffles() {
        let s1 = started(makeDuel(seedA: 1, seedB: 2))
        let s2 = started(makeDuel(seedA: 3, seedB: 4))
        // Extremamente improvável colidir
        XCTAssertNotEqual(s1.playerA.hand.map(\.name), s2.playerA.hand.map(\.name))
        XCTAssertNotEqual(s1.playerB.hand.map(\.name), s2.playerB.hand.map(\.name))
    }

    func test_isolation_playerARNGDoesNotAffectPlayerBDraw() {
        // Se seed do A mudar mas B mantiver, mão de B deve ficar idêntica.
        let s1 = started(makeDuel(seedA: 111, seedB: 555))
        let s2 = started(makeDuel(seedA: 999, seedB: 555))
        XCTAssertEqual(s1.playerB.hand.map(\.name), s2.playerB.hand.map(\.name),
                       "RNGs isolados: mudar seed do A não muda draw de B")
    }

    // ------------------------------------------------------------------
    // Start Duel
    // ------------------------------------------------------------------

    func test_startDuel_setsPhaseActive() {
        let s = started(makeDuel())
        XCTAssertEqual(s.phase, .active)
    }

    func test_startDuel_drawsFiveForActivePlayer() {
        let s = started(makeDuel())
        XCTAssertEqual(s.activePlayer.hand.count, 5)
    }

    func test_startDuel_drawsFiveForWaitingPlayer() {
        // MVP: ambos os players sacam 5 no início (não implementamos "Trench Coin"
        // Hearthstone-style porque energia é fixa 3 — segundo a jogar não precisa
        // vantagem compensatória).
        let s = started(makeDuel())
        XCTAssertEqual(s.waitingPlayer.hand.count, 5)
    }

    func test_startDuel_setsTurnToOne() {
        let s = started(makeDuel())
        XCTAssertEqual(s.turn, 1)
    }

    func test_startDuel_firstToPlayControlsTurn() {
        let s = started(makeDuel(first: bob))
        XCTAssertEqual(s.activePlayerID, bob)
    }

    func test_startDuel_rejectsSecondCall() {
        let s = started(makeDuel())
        let result = DuelEngine.apply(.startDuel, to: s)
        guard case .invalid(let reason) = result else {
            return XCTFail("Deveria rejeitar segundo startDuel")
        }
        XCTAssertEqual(reason, .duelAlreadyStarted)
    }

    // ------------------------------------------------------------------
    // Turn ownership & validation
    // ------------------------------------------------------------------

    func test_playCard_rejectedIfNotYourTurn() {
        // Alice começa. Bob tenta jogar.
        let s = started(makeDuel(first: alice))
        let result = DuelEngine.apply(
            .playCard(playerID: bob, handIndex: 0),
            to: s
        )
        guard case .invalid(let reason) = result else {
            return XCTFail("Deveria rejeitar")
        }
        XCTAssertEqual(reason, .notYourTurn)
    }

    func test_endTurn_rejectedIfNotYourTurn() {
        let s = started(makeDuel(first: alice))
        let result = DuelEngine.apply(.endTurn(playerID: bob), to: s)
        guard case .invalid(let reason) = result else {
            return XCTFail("Deveria rejeitar")
        }
        XCTAssertEqual(reason, .notYourTurn)
    }

    func test_playCard_invalidHandIndex() {
        let s = started(makeDuel())
        let result = DuelEngine.apply(
            .playCard(playerID: s.activePlayerID, handIndex: 99),
            to: s
        )
        guard case .invalid(let reason) = result else {
            return XCTFail("Deveria rejeitar")
        }
        XCTAssertEqual(reason, .invalidHandIndex)
    }

    // ------------------------------------------------------------------
    // End Turn — handoff + reset
    // ------------------------------------------------------------------

    func test_endTurn_swapsActivePlayer() {
        let s0 = started(makeDuel(first: alice))
        let s1 = apply(.endTurn(playerID: alice), s0)
        XCTAssertEqual(s1.activePlayerID, bob)
    }

    func test_endTurn_incrementsTurn() {
        let s0 = started(makeDuel(first: alice))
        XCTAssertEqual(s0.turn, 1)
        let s1 = apply(.endTurn(playerID: alice), s0)
        XCTAssertEqual(s1.turn, 2)
    }

    func test_endTurn_resetsBlockOfActiveEndingTurn() {
        // Alice ganha block, termina turno, block dela deveria zerar quando
        // o turno dela recomeçar. Testamos indireto: block de Alice deve estar
        // 0 depois que Bob termina o dele (turno de Alice recomeça).
        var s = started(makeDuel(first: alice))
        // Alice joga Formação Fechada (gainBlock 5) — assumindo que tá na mão inicial.
        // Se não estiver, forçamos: setamos block manualmente e testamos que zera.
        s.playerA.player.block = 5

        s = apply(.endTurn(playerID: alice), s)  // termina turno de Alice — bob vez
        XCTAssertEqual(s.playerA.player.block, 5, "Block persiste enquanto Bob joga")

        s = apply(.endTurn(playerID: bob), s)  // Bob termina, Alice recomeça
        XCTAssertEqual(s.playerA.player.block, 0, "Block de Alice zera no início do turno dela")
    }

    func test_endTurn_refillsEnergyOfIncomingPlayer() {
        var s = started(makeDuel(first: alice))
        // Simula que Bob gastou toda energia.
        s.playerB.player.energy = 0
        s = apply(.endTurn(playerID: alice), s)  // Bob vez
        XCTAssertEqual(s.playerB.player.energy, s.playerB.player.maxEnergy)
    }

    // ------------------------------------------------------------------
    // Effects — mapeamento single-player → PvP
    // ------------------------------------------------------------------

    func test_damage_hitsOpponentNotSelf() {
        var s = started(makeDuel(first: alice))
        // Injeta uma carta conhecida na mão de Alice pra teste determinístico.
        let atirar = Card(
            name: "Ordem: Atirar",
            cost: 1,
            type: .ordem,
            effects: [.damage(6)],
            targeting: .singleEnemy,
            templateID: "order_shoot"
        )
        s.playerA.hand = [atirar] + s.playerA.hand
        let hpBobBefore = s.playerB.player.hp
        let hpAliceBefore = s.playerA.player.hp

        let after = apply(.playCard(playerID: alice, handIndex: 0), s)

        XCTAssertEqual(after.playerB.player.hp, hpBobBefore - 6, "Bob leva 6 dano")
        XCTAssertEqual(after.playerA.player.hp, hpAliceBefore, "Alice não toma dano")
    }

    func test_gainBlock_appliesToSelfNotOpponent() {
        var s = started(makeDuel(first: alice))
        let formacao = Card(
            name: "Formação Fechada",
            cost: 1,
            type: .manobra,
            effects: [.gainBlock(5)],
            templateID: "close_formation"
        )
        s.playerA.hand = [formacao] + s.playerA.hand

        let after = apply(.playCard(playerID: alice, handIndex: 0), s)

        XCTAssertEqual(after.playerA.player.block, 5, "Alice ganha 5 block")
        XCTAssertEqual(after.playerB.player.block, 0, "Bob não ganha nada")
    }

    func test_blockAbsorbsIncomingDamage() {
        // Alice ataca Bob que tem block prévio. Bob perde block antes de HP.
        var s = started(makeDuel(first: alice))
        s.playerB.player.block = 4  // simulamos que Bob já tinha 4 block

        let atirar = Card(
            name: "Ordem: Atirar", cost: 1, type: .ordem,
            effects: [.damage(6)], targeting: .singleEnemy, templateID: "order_shoot"
        )
        s.playerA.hand = [atirar] + s.playerA.hand

        let hpBefore = s.playerB.player.hp
        let after = apply(.playCard(playerID: alice, handIndex: 0), s)

        XCTAssertEqual(after.playerB.player.block, 0, "Block de Bob consumido")
        XCTAssertEqual(after.playerB.player.hp, hpBefore - 2, "Bob leva só 2 (6 - 4 block)")
    }

    func test_gainMoral_cappedAtMaxMoral() {
        var s = started(makeDuel(first: alice))
        // Alice tá com 39/40 moral, joga carta que dá +5.
        s.playerA.player.moral = 39
        let reforcar = Card(
            name: "Reforçar Moral", cost: 1, type: .resolucao,
            effects: [.gainMoral(5)], templateID: "reinforce_moral"
        )
        s.playerA.hand = [reforcar] + s.playerA.hand

        let after = apply(.playCard(playerID: alice, handIndex: 0), s)

        XCTAssertEqual(after.playerA.player.moral, 40, "Moral capa em 40")
    }

    func test_skipNextTurn_makesOpponentSkip() {
        // Alice joga Empurrar Frente. Bob deve perder o próximo turno dele.
        var s = started(makeDuel(first: alice))
        let empurrar = Card(
            name: "Empurrar Frente", cost: 1, type: .manobra,
            effects: [.skipNextTurn], targeting: .singleEnemy, templateID: "push_forward"
        )
        s.playerA.hand = [empurrar] + s.playerA.hand

        s = apply(.playCard(playerID: alice, handIndex: 0), s)
        XCTAssertEqual(s.playerB.player.statusEffects[.skipNextTurn], 1,
                       "Bob marcado com skip")

        // Alice termina turno — Bob deveria pular direto e voltar pra Alice.
        s = apply(.endTurn(playerID: alice), s)
        XCTAssertEqual(s.activePlayerID, alice, "Voltou pra Alice sem Bob jogar")
        XCTAssertNil(s.playerB.player.statusEffects[.skipNextTurn],
                     "Skip foi consumido")
        XCTAssertEqual(s.turn, 3, "Dois handoffs = turn 3")

        // Confirma que os events do skip apareceram no recap do turno (previousTurnEvents,
        // já que events é zerado no fim do endTurn pra começar limpo o próximo turno).
        let hasSkippedEvent = s.previousTurnEvents.contains {
            if case .turnSkipped(let pid) = $0 { return pid == bob }
            return false
        }
        XCTAssertTrue(hasSkippedEvent)
    }

    func test_fear_reducesDamageOfAffectedPlayer() {
        // Alice está com 2 stacks de fear. Joga Ordem: Atirar (damage 6).
        // Efetivo = 6 - 2 = 4.
        var s = started(makeDuel(first: alice))
        s.playerA.player.statusEffects[.fear] = 2
        let atirar = Card(
            name: "Ordem: Atirar", cost: 1, type: .ordem,
            effects: [.damage(6)], targeting: .singleEnemy, templateID: "order_shoot"
        )
        s.playerA.hand = [atirar] + s.playerA.hand
        let hpBefore = s.playerB.player.hp

        let after = apply(.playCard(playerID: alice, handIndex: 0), s)

        XCTAssertEqual(after.playerB.player.hp, hpBefore - 4, "Fear reduziu dano de 6 pra 4")
    }

    func test_fear_decaysOneStackPerTurnOfAffected() {
        // Alice tem fear 3. Termina turno (vai pra Bob), Bob termina, Alice
        // recomeça. Ao ENTRAR no turno de Alice, fear deve decair pra 2.
        var s = started(makeDuel(first: alice))
        s.playerA.player.statusEffects[.fear] = 3

        s = apply(.endTurn(playerID: alice), s)  // Alice→Bob
        XCTAssertEqual(s.playerA.player.statusEffects[.fear], 3, "Não decai fora do turno dela")

        s = apply(.endTurn(playerID: bob), s)  // Bob→Alice
        XCTAssertEqual(s.playerA.player.statusEffects[.fear], 2, "Decai ao entrar turno dela")
    }

    // ------------------------------------------------------------------
    // Fadiga (No Man's Land)
    // ------------------------------------------------------------------

    func test_fatigue_dealsGrowingDamageWhenPileEmpty() {
        // Força pile e discard vazios, hand vazia, HP alto. Simula end turn.
        // Depois do handoff Alice → Bob → Alice, Alice tenta comprar 5 = 5x fadiga
        // crescente (1+2+3+4+5 = 15 HP).
        var s = started(makeDuel(first: alice))
        s.playerA.drawPile = []
        s.playerA.discardPile = []
        s.playerA.hand = []  // impede reshuffle
        s.playerA.exhaustPile = []
        let hpBefore = s.playerA.player.hp

        // Alice end turn (não tem nada pra descartar, tudo bem)
        s = apply(.endTurn(playerID: alice), s)
        s = apply(.endTurn(playerID: bob), s)  // volta pra Alice — draw 5 aqui

        // Alice deveria ter tomado 1+2+3+4+5 = 15 dano
        XCTAssertEqual(s.playerA.player.hp, hpBefore - 15)
        XCTAssertEqual(s.playerA.fatigueCounter, 5)
    }

    func test_fatigue_ignoresBlock() {
        var s = started(makeDuel(first: alice))
        s.playerA.drawPile = []
        s.playerA.discardPile = []
        s.playerA.hand = []
        s.playerA.player.block = 100  // absurdo — fadiga ainda deve doer

        s = apply(.endTurn(playerID: alice), s)
        s = apply(.endTurn(playerID: bob), s)

        XCTAssertLessThan(s.playerA.player.hp, s.playerA.player.maxHP)
    }

    func test_reshuffle_movesDiscardBackToDraw() {
        // Alice tem draw vazio + discard cheio. Tenta sacar → reshuffle.
        var s = started(makeDuel(first: alice))
        // Move todas as cartas da mão E do draw pro discard
        s.playerA.discardPile = s.playerA.drawPile + s.playerA.hand
        s.playerA.drawPile = []
        s.playerA.hand = []

        // End turn (bob→alice pra Alice sacar de novo)
        s = apply(.endTurn(playerID: alice), s)
        s = apply(.endTurn(playerID: bob), s)

        XCTAssertEqual(s.playerA.hand.count, 5, "Sacou 5 depois de reshuffle")
        XCTAssertEqual(s.playerA.discardPile.count, 0, "Discard esvaziado")
        // deckShuffled fica em previousTurnEvents (o snapshot do turno anterior),
        // não em events (que fica vazio no fim do endTurn).
        XCTAssertTrue(s.previousTurnEvents.contains(where: {
            if case .deckShuffled(let pid) = $0 { return pid == alice }
            return false
        }))
    }

    // ------------------------------------------------------------------
    // Events / previousTurnEvents behavior (acumular no turno + snapshot no handoff)
    // ------------------------------------------------------------------

    func test_events_accumulateWithinSameTurn() {
        // Alice joga duas cartas — events deve conter events de AMBAS (não zera entre).
        var s = started(makeDuel(first: alice))
        let atirar = Card(name: "Ordem: Atirar", cost: 1, type: .ordem,
                          effects: [.damage(6)], targeting: .singleEnemy, templateID: "order_shoot")
        let formacao = Card(name: "Formação Fechada", cost: 1, type: .manobra,
                            effects: [.gainBlock(5)], templateID: "close_formation")
        s.playerA.hand = [atirar, formacao] + s.playerA.hand

        s = apply(.playCard(playerID: alice, handIndex: 0), s)
        s = apply(.playCard(playerID: alice, handIndex: 0), s)

        let cardPlayedCount = s.events.filter {
            if case .cardPlayed = $0 { return true }
            return false
        }.count
        XCTAssertEqual(cardPlayedCount, 2, "Events acumula — 2 playCards visíveis")
    }

    func test_endTurn_movesEventsToPreviousTurnEventsAndClearsEvents() {
        var s = started(makeDuel(first: alice))
        let atirar = Card(name: "Ordem: Atirar", cost: 1, type: .ordem,
                          effects: [.damage(6)], targeting: .singleEnemy, templateID: "order_shoot")
        s.playerA.hand = [atirar] + s.playerA.hand

        s = apply(.playCard(playerID: alice, handIndex: 0), s)
        // events acumulado tem cardPlayed + damageDealt + cardDiscarded etc

        s = apply(.endTurn(playerID: alice), s)

        // Após endTurn: events zerado, previousTurnEvents tem tudo (playCard + fim do turno + start do Bob)
        XCTAssertTrue(s.events.isEmpty, "Events zerado pra próximo turno começar limpo")
        XCTAssertFalse(s.previousTurnEvents.isEmpty, "previousTurnEvents tem snapshot")
        XCTAssertTrue(s.previousTurnEvents.contains(where: {
            if case .cardPlayed = $0 { return true }
            return false
        }), "previousTurnEvents preserva o cardPlayed do turno da Alice")
        XCTAssertTrue(s.previousTurnEvents.contains(where: {
            if case .turnStarted(let pid, _) = $0 { return pid == bob }
            return false
        }), "previousTurnEvents inclui turnStarted(bob) — fecha a narrativa")
    }

    func test_previousTurnEvents_preservedThroughOpponentActions() {
        // Alice endTurn → previousTurnEvents populado.
        // Bob joga carta → previousTurnEvents deve continuar intacto (só events muda).
        var s = started(makeDuel(first: alice))
        let atirar = Card(name: "Ordem: Atirar", cost: 1, type: .ordem,
                          effects: [.damage(6)], targeting: .singleEnemy, templateID: "order_shoot")
        s.playerA.hand = [atirar] + s.playerA.hand

        s = apply(.playCard(playerID: alice, handIndex: 0), s)
        s = apply(.endTurn(playerID: alice), s)

        let snapshotBeforeBobPlays = s.previousTurnEvents

        // Bob joga uma carta (com o que tiver na mão dele)
        s = apply(.playCard(playerID: bob, handIndex: 0), s)

        XCTAssertEqual(s.previousTurnEvents.count, snapshotBeforeBobPlays.count,
                       "previousTurnEvents mantido durante action do Bob (só events acumula)")
        XCTAssertFalse(s.events.isEmpty, "events tem os events da carta que Bob acabou de jogar")
    }

    // ------------------------------------------------------------------
    // Fluxo PvP com decks customizados (Fase 8)
    // ------------------------------------------------------------------

    func test_createHostedDuel_startsInAwaitingOpponentDeck() {
        let hostDeck = DuelDeckConfig.starterEdmund.toCardList()
        let s = DuelFactory.createHostedDuel(
            hostID: alice,
            opponentID: bob,
            hostDeck: hostDeck,
            firstToPlay: alice,
            seedHost: 42,
            seedOpponent: 99
        )
        XCTAssertEqual(s.phase, .awaitingOpponentDeck)
        XCTAssertEqual(s.activePlayerID, bob, "Oponente precisa agir primeiro (submeter deck)")
        XCTAssertEqual(s.firstToPlayID, alice, "firstToPlayID preservado pro jogo")
        XCTAssertEqual(s.playerA.drawPile.count, 15, "Host já tem deck de 15 cartas")
        XCTAssertTrue(s.playerB.drawPile.isEmpty, "Oponente drawPile vazio (aguardando submissão)")
    }

    func test_startDuel_rejectedInAwaitingOpponentDeck() {
        let hostDeck = DuelDeckConfig.starterEdmund.toCardList()
        let s = DuelFactory.createHostedDuel(
            hostID: alice, opponentID: bob, hostDeck: hostDeck
        )
        let result = DuelEngine.apply(.startDuel, to: s)
        guard case .invalid(let reason) = result else {
            return XCTFail("startDuel deveria ser rejeitado em awaitingOpponentDeck")
        }
        XCTAssertEqual(reason, .duelAlreadyStarted)
    }

    func test_submitOpponentDeck_rejectedIfHostSubmits() {
        let hostDeck = DuelDeckConfig.starterEdmund.toCardList()
        let s = DuelFactory.createHostedDuel(
            hostID: alice, opponentID: bob, hostDeck: hostDeck
        )
        let result = DuelEngine.apply(
            .submitOpponentDeck(playerID: alice, deck: hostDeck),
            to: s
        )
        guard case .invalid(let reason) = result else {
            return XCTFail("Host não pode submeter em nome do oponente")
        }
        XCTAssertEqual(reason, .hostCantSubmitOpponentDeck)
    }

    func test_submitOpponentDeck_rejectedIfEmpty() {
        let hostDeck = DuelDeckConfig.starterEdmund.toCardList()
        let s = DuelFactory.createHostedDuel(
            hostID: alice, opponentID: bob, hostDeck: hostDeck
        )
        let result = DuelEngine.apply(
            .submitOpponentDeck(playerID: bob, deck: []),
            to: s
        )
        guard case .invalid(let reason) = result else {
            return XCTFail("Deck vazio deveria ser rejeitado")
        }
        XCTAssertEqual(reason, .deckEmpty)
    }

    func test_submitOpponentDeck_transitionsToActiveAndRestoresFirstToPlay() {
        let hostDeck = DuelDeckConfig.starterEdmund.toCardList()
        let opponentDeck = DuelDeckConfig.starterEdmund.toCardList()
        let s0 = DuelFactory.createHostedDuel(
            hostID: alice, opponentID: bob, hostDeck: hostDeck,
            firstToPlay: alice, seedHost: 42, seedOpponent: 99
        )
        // Antes: activePlayerID = bob (esperando submissão)
        let s1 = apply(.submitOpponentDeck(playerID: bob, deck: opponentDeck), s0)

        XCTAssertEqual(s1.phase, .active, "Após submissão + startDuel, fase ativa")
        XCTAssertEqual(s1.activePlayerID, alice, "Vez restaurada pro firstToPlay original")
        XCTAssertEqual(s1.playerA.hand.count, 5, "Host sacou mão inicial")
        XCTAssertEqual(s1.playerB.hand.count, 5, "Oponente sacou mão inicial")
        XCTAssertEqual(s1.playerA.drawPile.count, 10, "Host: 15 - 5 sacadas = 10 no deck")
        XCTAssertEqual(s1.playerB.drawPile.count, 10, "Oponente: 15 - 5 sacadas = 10 no deck")
        XCTAssertEqual(s1.turn, 1)
    }

    func test_submitOpponentDeck_rejectedInWrongPhase() {
        // Aplica submitOpponentDeck em state já ativo → deveria falhar
        var s = started(makeDuel(first: alice))  // .active
        let result = DuelEngine.apply(
            .submitOpponentDeck(playerID: alice, deck: DuelDeckConfig.starterEdmund.toCardList()),
            to: s
        )
        guard case .invalid(let reason) = result else {
            return XCTFail("submitOpponentDeck em .active deveria falhar")
        }
        XCTAssertEqual(reason, .notInDeckSubmissionPhase)
        _ = s  // silence warning
    }

    // ------------------------------------------------------------------
    // DuelDeckConfig — validação e materialização
    // ------------------------------------------------------------------

    func test_deckConfig_starterEdmundIsValid() {
        let config = DuelDeckConfig.starterEdmund
        XCTAssertNil(config.validate(), "Starter Edmund deve ser válido")
        XCTAssertEqual(config.totalCards, 15)
    }

    func test_deckConfig_wrongSizeIsRejected() {
        var config = DuelDeckConfig.starterEdmund
        config.setCount(0, for: "order_shoot")  // remove 2 → total 13
        guard case .wrongSize(let actual, let required) = config.validate() else {
            return XCTFail("Deveria falhar com wrongSize")
        }
        XCTAssertEqual(actual, 13)
        XCTAssertEqual(required, 15)
    }

    func test_deckConfig_setCountClampsToMax() {
        var config = DuelDeckConfig()
        config.setCount(5, for: "order_shoot")  // maxCopies = 2
        XCTAssertEqual(config.count(for: "order_shoot"), 2, "Clamp em max")
    }

    func test_deckConfig_setCountZeroRemovesEntry() {
        var config = DuelDeckConfig(counts: ["order_shoot": 2])
        config.setCount(0, for: "order_shoot")
        XCTAssertFalse(config.counts.keys.contains("order_shoot"))
    }

    func test_deckConfig_unknownTemplateIsRejected() {
        // Deck com total válido (15) mas contendo templateID desconhecido
        let config = DuelDeckConfig(counts: [
            "order_shoot":     2,
            "close_formation": 2,
            "counter_attack":  2,
            "push_forward":    2,
            "reinforce_moral": 2,
            "rationalize":     2,
            "order_shout":     1,
            "unknown_xyz":     2,  // ← inválido
        ])
        // Total = 15 ✓ (passa wrongSize)
        XCTAssertEqual(config.totalCards, 15)
        guard case .unknownTemplate(let tid) = config.validate() else {
            return XCTFail("Deveria falhar com unknownTemplate, deu \(String(describing: config.validate()))")
        }
        XCTAssertEqual(tid, "unknown_xyz")
    }

    func test_deckConfig_toCardList_producesFreshUUIDs() {
        let config = DuelDeckConfig.starterEdmund
        let list1 = config.toCardList()
        let list2 = config.toCardList()
        XCTAssertEqual(list1.count, 15)
        XCTAssertEqual(list2.count, 15)
        // Cada chamada gera UUIDs novos — nenhum id compartilhado entre calls
        let ids1 = Set(list1.map(\.id))
        let ids2 = Set(list2.map(\.id))
        XCTAssertTrue(ids1.isDisjoint(with: ids2), "toCardList() gera UUIDs frescos")
    }

    func test_deckConfig_toCardList_respectsTemplateCounts() {
        let config = DuelDeckConfig(counts: [
            "order_shoot": 2,
            "close_formation": 2,
            "counter_attack": 2,
            "push_forward": 2,
            "reinforce_moral": 2,
            "rationalize": 2,
            "order_shout": 1,
            "order_retreat": 2,
        ])
        let cards = config.toCardList()
        let shootCount = cards.filter { $0.templateID == "order_shoot" }.count
        let shoutCount = cards.filter { $0.templateID == "order_shout" }.count
        XCTAssertEqual(shootCount, 2)
        XCTAssertEqual(shoutCount, 1)
    }

    func test_deckConfig_codableRoundTrip() throws {
        let original = DuelDeckConfig.starterEdmund
        let data = try JSONEncoder().encode(original)
        let recovered = try JSONDecoder().decode(DuelDeckConfig.self, from: data)
        XCTAssertEqual(recovered, original)
    }

    // ------------------------------------------------------------------
    // Fim de duelo
    // ------------------------------------------------------------------

    func test_duelEnds_whenOpponentHPHitsZero() {
        var s = started(makeDuel(first: alice))
        s.playerB.player.hp = 3  // Bob quase morto

        let atirar = Card(
            name: "Ordem: Atirar", cost: 1, type: .ordem,
            effects: [.damage(6)], targeting: .singleEnemy, templateID: "order_shoot"
        )
        s.playerA.hand = [atirar] + s.playerA.hand

        let after = apply(.playCard(playerID: alice, handIndex: 0), s)

        XCTAssertTrue(after.isDuelOver)
        XCTAssertEqual(after.winnerID, alice)
    }

    func test_duelEnds_whenOpponentMoralHitsZero() {
        // Bob com moral 1. Alice não tem carta de moral attack no starter, então
        // simulamos com effect direto: damageSelfMoral em Bob... espera,
        // damageSelfMoral atinge o ATOR, não o oponente. Então tem que usar
        // moralAttack via intent — mas isso é single-player.
        //
        // No MVP com deck starter do Edmund, NENHUMA carta faz moral damage no
        // oponente. Isso é design intencional (esse teste documenta que).
        //
        // Só damageSelfMoral existe e sempre atinge o próprio player. Se Alice
        // se auto-danificar até moral 0, Bob ganha.
        var s = started(makeDuel(first: alice))
        s.playerA.player.moral = 1

        // Simulamos com carta injetada (self-moral-damage crítica).
        let sacrificar = Card(
            name: "Auto-dano teste", cost: 0, type: .corrupcao,
            effects: [.damageSelfMoral(5)], templateID: "test_self_moral"
        )
        s.playerA.hand = [sacrificar] + s.playerA.hand

        let after = apply(.playCard(playerID: alice, handIndex: 0), s)

        XCTAssertTrue(after.isDuelOver)
        XCTAssertEqual(after.winnerID, bob, "Bob vence porque Alice se matou de moral")
    }

    func test_forfeit_endsWithOpponentAsWinner() {
        let s0 = started(makeDuel(first: alice))
        let s1 = apply(.forfeit(playerID: alice), s0)
        XCTAssertTrue(s1.isDuelOver)
        XCTAssertEqual(s1.winnerID, bob)
    }

    // ------------------------------------------------------------------
    // Serialização (o que garante que matchData funciona)
    // ------------------------------------------------------------------

    func test_duelState_isFullyCodable() throws {
        let s0 = started(makeDuel(first: alice, seedA: 42, seedB: 99))

        let encoded = try JSONEncoder().encode(s0)
        let decoded = try JSONDecoder().decode(DuelState.self, from: encoded)

        XCTAssertEqual(decoded, s0, "Round-trip encode/decode preserva state completo")
    }

    func test_duelState_serializedSizeFitsInMatchData() throws {
        let s0 = started(makeDuel())
        let encoded = try JSONEncoder().encode(s0)
        // Limite Apple é 64 KB. Warn se passar de 20 KB (folga generosa).
        XCTAssertLessThan(encoded.count, 20_480,
                          "DuelState serializado deveria ficar <20KB. Atual: \(encoded.count) bytes")
    }

    func test_replay_deterministicAfterRoundTrip() throws {
        // Serializa → deserializa → aplica mesma action → mesmo resultado.
        let s0 = started(makeDuel(first: alice, seedA: 42, seedB: 99))
        let encoded = try JSONEncoder().encode(s0)
        let recovered = try JSONDecoder().decode(DuelState.self, from: encoded)

        let action = DuelAction.endTurn(playerID: alice)
        let fromOriginal = apply(action, s0)
        let fromRecovered = apply(action, recovered)

        XCTAssertEqual(fromOriginal, fromRecovered,
                       "Same action em state serializado/deserializado dá mesmo output")
    }

    // ------------------------------------------------------------------
    // Utils
    // ------------------------------------------------------------------

    private func apply(_ action: DuelAction, _ state: DuelState) -> DuelState {
        guard case .applied(let s) = DuelEngine.apply(action, to: state) else {
            XCTFail("Action \(action) falhou (esperava sucesso)")
            return state
        }
        return s
    }
}
