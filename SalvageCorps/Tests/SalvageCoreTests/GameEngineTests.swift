import XCTest
@testable import SalvageCore

final class GameEngineTests: XCTestCase {

    // ----------------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------------

    private func makeState(
        deck: [Card] = StarterDeck.edmundStartingDeck(),
        enemies: [Enemy] = [StarterEnemies.recrutaAlemao()],
        seed: UInt64 = 42
    ) -> GameState {
        GameState(
            player: PlayerState(),
            enemies: enemies,
            deck: deck,
            seed: seed
        )
    }

    private func started(_ state: GameState) -> GameState {
        guard case .applied(let s) = GameEngine.apply(.startCombat, to: state) else {
            XCTFail("startCombat falhou")
            return state
        }
        return s
    }

    // ----------------------------------------------------------------------
    // Determinismo (crítico — se quebra, tudo mais é aleatório)
    // ----------------------------------------------------------------------

    func test_determinism_sameSeedProducesSameShuffle() {
        let s1 = started(makeState(seed: 12345))
        let s2 = started(makeState(seed: 12345))
        XCTAssertEqual(s1.hand.map(\.name), s2.hand.map(\.name),
                       "Mesma seed deve produzir mesmo shuffle. Se falhou, RNG não é determinístico.")
    }

    func test_determinism_differentSeedProducesDifferentShuffle() {
        let s1 = started(makeState(seed: 111))
        let s2 = started(makeState(seed: 222))
        // Extremamente improvável duas seeds diferentes produzirem mesma ordem
        XCTAssertNotEqual(s1.hand.map(\.name), s2.hand.map(\.name))
    }

    // ----------------------------------------------------------------------
    // Start Combat
    // ----------------------------------------------------------------------

    func test_startCombat_dealsHandOfFive() {
        let s = started(makeState())
        XCTAssertEqual(s.hand.count, 5)
        XCTAssertEqual(s.drawPile.count, 5, "10 cartas totais, 5 na mão, 5 no deck")
        XCTAssertEqual(s.phase, .playerTurn)
        XCTAssertEqual(s.turn, 1)
        XCTAssertEqual(s.player.energy, 3)
    }

    func test_startCombat_twiceIsInvalid() {
        let s = started(makeState())
        let result = GameEngine.apply(.startCombat, to: s)
        guard case .invalid(let err) = result else {
            XCTFail("Deveria falhar em startCombat duplicado")
            return
        }
        XCTAssertEqual(err, .combatAlreadyStarted)
    }

    // ----------------------------------------------------------------------
    // Play Card — validações
    // ----------------------------------------------------------------------

    func test_playCard_invalidHandIndex() {
        let s = started(makeState())
        let result = GameEngine.apply(.playCard(handIndex: 99), to: s)
        guard case .invalid(let err) = result else {
            XCTFail("Deveria falhar em índice inválido")
            return
        }
        XCTAssertEqual(err, .invalidHandIndex)
    }

    func test_playCard_notEnoughEnergy() {
        // Constrói cenário: mão com 3 cartas de custo 2 cada, energia 3
        // Joga 2 → energia = -1 na segunda? Não. Deve rejeitar segunda.
        let costlyCard = Card(name: "Custo Alto", cost: 3, type: .ordem,
                              effects: [.gainBlock(1)])
        var s = makeState(deck: [costlyCard, costlyCard, costlyCard, costlyCard, costlyCard])
        s = started(s)

        // Joga uma carta de custo 3 (energia 3 → 0)
        guard case .applied(let s1) = GameEngine.apply(.playCard(handIndex: 0), to: s) else {
            XCTFail("Primeira carta deveria funcionar")
            return
        }
        XCTAssertEqual(s1.player.energy, 0)

        // Tenta jogar segunda carta de custo 3 (energia 0)
        let result = GameEngine.apply(.playCard(handIndex: 0), to: s1)
        guard case .invalid(let err) = result else {
            XCTFail("Segunda carta deveria falhar por energia")
            return
        }
        XCTAssertEqual(err, .notEnoughEnergy)
    }

    func test_playCard_targetRequiredButMissing() {
        // Uma carta que requer target sem passar target
        let s = started(makeState(deck: [
            Card(name: "Ataca", cost: 1, type: .ordem,
                 effects: [.damage(5)], targeting: .singleEnemy)
        ] + Array(repeating: Card(name: "Filler", cost: 0, type: .manobra, effects: []), count: 5)))

        // Encontra a carta "Ataca" na mão
        guard let idx = s.hand.firstIndex(where: { $0.name == "Ataca" }) else {
            XCTFail("Carta 'Ataca' não está na mão inicial (raro dado o seed — ajuste)")
            return
        }
        let result = GameEngine.apply(.playCard(handIndex: idx), to: s)
        guard case .invalid(let err) = result else {
            XCTFail("Deveria falhar por targetRequired")
            return
        }
        XCTAssertEqual(err, .targetRequired)
    }

    // ----------------------------------------------------------------------
    // Damage & Block
    // ----------------------------------------------------------------------

    func test_damage_reducesEnemyHP() {
        var s = started(makeState())
        let enemyID = s.enemies[0].id
        let initialHP = s.enemies[0].hp

        // Injeta carta de dano na mão (mais controlável que depender de shuffle)
        s.hand = [
            Card(name: "Test Hit", cost: 1, type: .ordem,
                 effects: [.damage(7)], targeting: .singleEnemy)
        ]

        guard case .applied(let after) = GameEngine.apply(
            .playCard(handIndex: 0, targetEnemyID: enemyID),
            to: s
        ) else {
            XCTFail("Play deveria funcionar")
            return
        }

        XCTAssertEqual(after.enemies[0].hp, initialHP - 7)
    }

    func test_block_absorbsDamage() {
        var s = started(makeState())
        s.player.block = 5
        s.hand = [
            Card(name: "End", cost: 0, type: .manobra, effects: [])
        ]

        // Substitui inimigo por um que dá dano 3
        s.enemies = [Enemy(
            name: "TestEnemy",
            maxHP: 20,
            intentPattern: IntentPattern([.attack(damage: 3)])
        )]

        guard case .applied(let after) = GameEngine.apply(.endTurn, to: s) else {
            XCTFail("End turn deveria funcionar")
            return
        }

        // Dano 3 absorvido totalmente pelo block 5
        XCTAssertEqual(after.player.hp, 60)
        // Block reseta no início do turno do jogador — deve estar 0 agora
        XCTAssertEqual(after.player.block, 0)
    }

    func test_block_overflowDamageHitsHP() {
        var s = started(makeState())
        s.player.block = 2
        s.hand = [Card(name: "End", cost: 0, type: .manobra, effects: [])]
        s.enemies = [Enemy(
            name: "Hard Hitter",
            maxHP: 20,
            intentPattern: IntentPattern([.attack(damage: 10)])
        )]

        guard case .applied(let after) = GameEngine.apply(.endTurn, to: s) else {
            XCTFail("End turn deveria funcionar")
            return
        }

        // 10 dano - 2 block = 8 no HP. HP 60 → 52
        XCTAssertEqual(after.player.hp, 52)
    }

    // ----------------------------------------------------------------------
    // Moral system (a signature mechanic)
    // ----------------------------------------------------------------------

    func test_moralAttack_ignoresBlock() {
        var s = started(makeState())
        s.player.block = 100  // muito block
        s.hand = [Card(name: "End", cost: 0, type: .manobra, effects: [])]
        s.enemies = [Enemy(
            name: "Psychic",
            maxHP: 20,
            intentPattern: IntentPattern([.moralAttack(damage: 5)])
        )]

        guard case .applied(let after) = GameEngine.apply(.endTurn, to: s) else {
            XCTFail("End turn deveria funcionar")
            return
        }

        // Moral deve ter caído mesmo com 100 de block
        XCTAssertEqual(after.player.moral, 35)
        XCTAssertEqual(after.player.hp, 60)  // HP intacto
    }

    func test_moralZero_triggersDefeat() {
        var s = started(makeState())
        s.player.moral = 3
        s.hand = [Card(name: "End", cost: 0, type: .manobra, effects: [])]
        s.enemies = [Enemy(
            name: "Psychic",
            maxHP: 20,
            intentPattern: IntentPattern([.moralAttack(damage: 5)])
        )]

        guard case .applied(let after) = GameEngine.apply(.endTurn, to: s) else {
            XCTFail("End turn deveria funcionar")
            return
        }

        XCTAssertEqual(after.player.moral, 0)
        XCTAssertEqual(after.phase, .defeat(reason: .moral))
        XCTAssertTrue(after.isCombatOver)
    }

    func test_reforcarMoral_healsMoral() {
        var s = started(makeState())
        s.player.moral = 20
        s.hand = [
            Card(name: "Reforçar Moral", cost: 1, type: .resolucao,
                 effects: [.gainMoral(5)])
        ]

        guard case .applied(let after) = GameEngine.apply(.playCard(handIndex: 0), to: s) else {
            XCTFail()
            return
        }

        XCTAssertEqual(after.player.moral, 25)
    }

    func test_gainMoral_cappedByMax() {
        var s = started(makeState())
        s.player.moral = 38  // maxMoral = 40 por default
        s.hand = [
            Card(name: "Big Heal", cost: 1, type: .resolucao,
                 effects: [.gainMoral(10)])
        ]

        guard case .applied(let after) = GameEngine.apply(.playCard(handIndex: 0), to: s) else {
            XCTFail()
            return
        }

        XCTAssertEqual(after.player.moral, 40, "Moral não pode ultrapassar maxMoral")
    }

    // ----------------------------------------------------------------------
    // Fear status effect
    // ----------------------------------------------------------------------

    func test_fear_reducesEnemyDamage() {
        var s = started(makeState())
        s.hand = [Card(name: "End", cost: 0, type: .manobra, effects: [])]
        var enemy = Enemy(
            name: "Fearful",
            maxHP: 20,
            intentPattern: IntentPattern([.attack(damage: 10)])
        )
        enemy.statusEffects[.fear] = 4  // Fear 4 → dano 10 vira 6
        s.enemies = [enemy]

        guard case .applied(let after) = GameEngine.apply(.endTurn, to: s) else {
            XCTFail()
            return
        }

        // HP 60 - 6 = 54 (não 50)
        XCTAssertEqual(after.player.hp, 54)
        // Fear decrementou 1 depois do ataque
        XCTAssertEqual(after.enemies[0].statusEffects[.fear], 3)
    }

    func test_fear_cantReduceBelowZero() {
        var s = started(makeState())
        s.hand = [Card(name: "End", cost: 0, type: .manobra, effects: [])]
        var enemy = Enemy(
            name: "Terrified",
            maxHP: 20,
            intentPattern: IntentPattern([.attack(damage: 3)])
        )
        enemy.statusEffects[.fear] = 10
        s.enemies = [enemy]

        guard case .applied(let after) = GameEngine.apply(.endTurn, to: s) else {
            XCTFail()
            return
        }

        // 3 - 10 = -7, mas dano nunca é negativo. HP intacto.
        XCTAssertEqual(after.player.hp, 60)
    }

    // ----------------------------------------------------------------------
    // Victory condition
    // ----------------------------------------------------------------------

    func test_killingLastEnemy_triggersVictory() {
        var s = started(makeState(enemies: [
            Enemy(name: "Weak", maxHP: 3,
                  intentPattern: IntentPattern([.attack(damage: 1)]))
        ]))

        s.hand = [Card(name: "Kill", cost: 1, type: .ordem,
                       effects: [.damage(10)], targeting: .singleEnemy)]

        let enemyID = s.enemies[0].id
        guard case .applied(let after) = GameEngine.apply(
            .playCard(handIndex: 0, targetEnemyID: enemyID),
            to: s
        ) else {
            XCTFail()
            return
        }

        XCTAssertEqual(after.phase, .victory)
        XCTAssertTrue(after.isCombatOver)
    }

    // ----------------------------------------------------------------------
    // Draw pile reshuffle
    // ----------------------------------------------------------------------

    func test_drawPileReshuffles_whenEmpty() {
        // Cenário: deck de 1 carta, joga, força reshuffle
        let card = Card(name: "Small", cost: 0, type: .manobra, effects: [])
        var s = makeState(deck: [card])
        s = started(s)
        // Após startCombat, hand tem 1 carta e draw pile tem 0.

        XCTAssertEqual(s.hand.count, 1)
        XCTAssertEqual(s.drawPile.count, 0)

        // Descarta a carta jogando ela
        guard case .applied(let s1) = GameEngine.apply(.playCard(handIndex: 0), to: s) else {
            XCTFail()
            return
        }
        XCTAssertEqual(s1.hand.count, 0)
        XCTAssertEqual(s1.discardPile.count, 1)

        // Coloca inimigo passivo pra endTurn não matar
        var s2 = s1
        s2.enemies = [Enemy(name: "Idle", maxHP: 20,
                            intentPattern: IntentPattern([.defend(block: 0)]))]

        guard case .applied(let s3) = GameEngine.apply(.endTurn, to: s2) else {
            XCTFail()
            return
        }

        // Após endTurn: reshuffle aconteceu, hand deve ter a carta de volta
        XCTAssertEqual(s3.hand.count, 1)
        XCTAssertEqual(s3.discardPile.count, 0)
        XCTAssertTrue(s3.events.contains(.deckShuffled))
    }

    // ----------------------------------------------------------------------
    // Exhaust flow — Racionalizar
    // ----------------------------------------------------------------------

    func test_racionalizar_exhaustsChosenAndGivesMoral() {
        var s = started(makeState())
        s.player.moral = 20
        s.hand = [
            Card(name: "Racionalizar", cost: 0, type: .resolucao,
                 effects: [.exhaustChosenFromHand, .gainMoral(3)],
                 targeting: .cardInHand),
            Card(name: "Vítima", cost: 1, type: .ordem, effects: []),
            Card(name: "Outra", cost: 1, type: .ordem, effects: []),
        ]

        guard case .applied(let after) = GameEngine.apply(
            .playCard(handIndex: 0, targetHandIndex: 1),
            to: s
        ) else {
            XCTFail()
            return
        }

        XCTAssertEqual(after.player.moral, 23)
        XCTAssertEqual(after.hand.count, 1, "1 carta restante (outra)")
        XCTAssertEqual(after.exhaustPile.count, 1)
        XCTAssertEqual(after.exhaustPile.first?.name, "Vítima")
        // Racionalizar em si vai pro discard, não exhaust
        XCTAssertEqual(after.discardPile.count, 1)
        XCTAssertEqual(after.discardPile.first?.name, "Racionalizar")
    }

    // ----------------------------------------------------------------------
    // Serialização (garante Codable funciona pra save/replay)
    // ----------------------------------------------------------------------

    func test_gameStateIsCodable() throws {
        let s = started(makeState())
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(s, decoded, "Round-trip Codable deve preservar estado exato")
    }
}
