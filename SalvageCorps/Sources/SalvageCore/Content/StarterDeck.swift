import Foundation

/// Deck starter do Edmund Vale.
///
/// Cada carta tem `templateID` estável, permitindo o sistema de cicatrizes
/// mapear upgrades por template. Use `buildDeck(with:)` pra construir um deck
/// concreto aplicando os upgrades escolhidos no PlayerDeck.
public enum StarterDeck {

    /// Deck base sem upgrades. Usado por `buildDeck(with:)` internamente.
    /// Se você quiser um deck cru pra testes/preview, use este.
    public static func edmundStartingDeck() -> [Card] {
        buildDeck(with: PlayerDeck())
    }

    /// Constrói o deck concreto aplicando os upgrades definidos no PlayerDeck.
    /// Inclui cartas starter (com upgrades) + extras adicionadas via eventos.
    public static func buildDeck(with playerDeck: PlayerDeck) -> [Card] {
        // 1. Templates starter (com upgrades aplicados se houver)
        var deck = templates().map { template in
            guard let templateID = template.templateID,
                  let upgradeID = playerDeck.upgradeIDFor(templateID: templateID),
                  let upgrade = UpgradeCatalog.upgrades(for: templateID)
                    .first(where: { $0.id == upgradeID })
            else {
                return template
            }
            return template.applyingUpgrade(upgrade)
        }

        // 2. Cartas extras (adicionadas via events). Cada string em extraCards
        //    representa uma cópia — pode ter duplicatas.
        for extraID in playerDeck.extraCards {
            guard let extraCard = extraCardTemplate(for: extraID) else { continue }
            // Aplica upgrade da carta extra também, se houver
            if let upgradeID = playerDeck.upgradeIDFor(templateID: extraID),
               let upgrade = UpgradeCatalog.upgrades(for: extraID)
                .first(where: { $0.id == upgradeID }) {
                deck.append(extraCard.applyingUpgrade(upgrade))
            } else {
                deck.append(extraCard)
            }
        }

        return deck
    }

    /// Retorna templates únicos disponíveis pra upgrade — starter + extras
    /// atualmente no deck do player. Usado pelo picker do Refletir.
    public static func uniqueTemplates(with playerDeck: PlayerDeck = PlayerDeck()) -> [Card] {
        var seen = Set<String>()
        var result: [Card] = []

        // Templates starter
        for card in templates() {
            guard let tid = card.templateID, !seen.contains(tid) else { continue }
            seen.insert(tid)
            result.append(card)
        }

        // Templates de extras (dedup pra não repetir se player tem 2 cópias)
        for extraID in playerDeck.uniqueExtraTemplateIDs {
            guard !seen.contains(extraID),
                  let card = extraCardTemplate(for: extraID) else { continue }
            seen.insert(extraID)
            result.append(card)
        }

        return result
    }

    /// Versão legacy sem parâmetro — só templates starter.
    public static func uniqueTemplates() -> [Card] {
        uniqueTemplates(with: PlayerDeck())
    }

    // MARK: - Templates (cria uma nova instância cada vez pra UUIDs únicos)

    private static func templates() -> [Card] {
        var deck: [Card] = []

        // 2x Ordem: Atirar
        for _ in 0..<2 {
            deck.append(Card(
                name: "Ordem: Atirar",
                cost: 1,
                type: .ordem,
                effects: [.damage(6)],
                targeting: .singleEnemy,
                flavor: "Fogo à vontade.",
                templateID: "order_shoot",
                artFilename: "card_ordem_atirar"
            ))
        }

        // 2x Formação Fechada
        for _ in 0..<2 {
            deck.append(Card(
                name: "Formação Fechada",
                cost: 1,
                type: .manobra,
                effects: [.gainBlock(5)],
                flavor: "Manter posição a todo custo.",
                templateID: "close_formation",
                artFilename: "card_formacao_fechada"
            ))
        }

        // 1x Empurrar Frente
        deck.append(Card(
            name: "Empurrar Frente",
            cost: 1,
            type: .manobra,
            effects: [.skipNextTurn],
            targeting: .singleEnemy,
            flavor: "Não deixe-os avançar.",
            templateID: "push_forward",
            artFilename: "card_empurrar_frente"
        ))

        // 1x Reforçar Moral
        deck.append(Card(
            name: "Reforçar Moral",
            cost: 1,
            type: .resolucao,
            effects: [.gainMoral(5)],
            flavor: "Pelo Rei e pela pátria.",
            templateID: "reinforce_moral",
            artFilename: "card_reforcar_moral"
        ))

        // 1x Grito de Ordem
        deck.append(Card(
            name: "Grito de Ordem",
            cost: 2,
            type: .ordem,
            effects: [
                .damageAll(4),
                .applyStatusAll(.fear, stacks: 2),
            ],
            flavor: "SEGURA A LINHA!",
            templateID: "order_shout",
            artFilename: "card_grito_de_ordem"
        ))

        // 1x Racionalizar
        deck.append(Card(
            name: "Racionalizar",
            cost: 0,
            type: .resolucao,
            effects: [
                .exhaustChosenFromHand,
                .gainMoral(3),
            ],
            targeting: .cardInHand,
            flavor: "Não foi você. Foi a guerra.",
            templateID: "rationalize",
            artFilename: "card_racionalizar"
        ))

        // 1x Contra-Ataque
        deck.append(Card(
            name: "Contra-Ataque",
            cost: 1,
            type: .manobra,
            effects: [
                .damage(3),
                .gainBlock(3),
            ],
            targeting: .singleEnemy,
            flavor: "Cada golpe merece resposta.",
            templateID: "counter_attack",
            artFilename: "card_contra_ataque"
        ))

        // 1x Ordem: Recuar
        deck.append(Card(
            name: "Ordem: Recuar",
            cost: 2,
            type: .ordem,
            effects: [.gainBlock(8)],
            flavor: "Regrupar e reagir.",
            templateID: "order_retreat",
            artFilename: "card_ordem_recuar"
        ))

        return deck
    }

    // MARK: - Cartas extras (obtidas por escolhas terminais — não no starter)

    public static func testemunhaSilenciada() -> Card {
        Card(
            name: "Testemunha Silenciada",
            cost: 0,
            type: .corrupcao,
            effects: [.damage(4)],
            targeting: .singleEnemy,
            flavor: "Ele não viu nada. Ninguém viu.",
            templateID: "silenced_witness",
            artFilename: "card_testemunha_silenciada"
        )
    }

    public static func consciencia() -> Card {
        Card(
            name: "Consciência",
            cost: 1,
            type: .resolucao,
            effects: [.gainMoral(5)],
            flavor: "Pequenas coisas importam.",
            templateID: "conscience",
            artFilename: "card_consciencia",
            retain: true
        )
    }

    // MARK: - Cartas do Ato 2 (adquiridas via eventos)

    /// Liberação de Gás — dano em área + medo em todos. 2 cost.
    /// Obtida via evento "Frasco Estranho".
    public static func gasRelease() -> Card {
        Card(
            name: "Liberação de Gás",
            cost: 2,
            type: .ordem,
            effects: [
                .damageAll(3),
                .applyStatusAll(.fear, stacks: 2),
            ],
            flavor: "O vento vira contra ele.",
            templateID: "gas_release",
            artFilename: "card_gas_release"
        )
    }

    /// Reserva Silenciosa — bloco pequeno mas retain. 0 cost.
    /// Obtida via escolha "Confiar" no Ashcroft Revelation.
    public static func silentReserve() -> Card {
        Card(
            name: "Reserva Silenciosa",
            cost: 0,
            type: .manobra,
            effects: [.gainBlock(4)],
            flavor: "Não use quando não precisar.",
            templateID: "silent_reserve",
            artFilename: "card_reserva_silenciosa",
            retain: true
        )
    }

    /// Sussurrar Verdade — sacrifica moral por dano massivo. 1 cost.
    /// Obtida via evento "Diário Rasgado".
    public static func whisperTruth() -> Card {
        Card(
            name: "Sussurrar Verdade",
            cost: 1,
            type: .corrupcao,
            effects: [
                .damageSelfMoral(2),
                .damage(12),
            ],
            targeting: .singleEnemy,
            flavor: "\u{201C}Isso não é humano.\u{201D}",
            templateID: "whisper_truth",
            artFilename: "card_sussurrar_verdade"
        )
    }

    /// Escuta Atenta — revela intents de TODOS os inimigos por 1 turno.
    /// Essencial contra Fog of War do Ato 2. Retain — sempre disponível.
    /// Obtida via evento "Posto de Escuta Abandonado".
    public static func attentiveListen() -> Card {
        Card(
            name: "Escuta Atenta",
            cost: 0,
            type: .manobra,
            effects: [.revealAllIntents],
            flavor: "Colocar a orelha na terra.",
            templateID: "attentive_listen",
            artFilename: "card_escuta_atenta",
            retain: true
        )
    }

    // MARK: - Cartas Ghost H. (Ato 3 — meta layer)
    // Injetadas AUTOMATICAMENTE no deck durante o Ato 3 em momentos específicos.
    // Player não escolheu ter. Contam pra ativar condições do ending "O Espelho".
    // Todas .corrupcao — acumulam stacks quando jogadas.

    /// H. Silêncio — bloco forte grátis mas retorna corruption. Retain.
    /// Injetada após primeiro combate do Ato 3.
    public static func ghostH1() -> Card {
        Card(
            name: "H. Silêncio",
            cost: 0,
            type: .corrupcao,
            effects: [.gainBlock(6)],
            flavor: "\u{201C}Você não precisa dizer nada.\u{201D}",
            templateID: "ghost_h_1",
            artFilename: "card_ghost_h_1",
            retain: true
        )
    }

    /// H. Presença — dano alto single-target mas custa moral.
    /// Injetada após primeiro camp do Ato 3.
    public static func ghostH2() -> Card {
        Card(
            name: "H. Presença",
            cost: 1,
            type: .corrupcao,
            effects: [
                .damageSelfMoral(3),
                .damage(15),
            ],
            targeting: .singleEnemy,
            flavor: "\u{201C}Ele te ajuda uma vez. Não pergunte por quê.\u{201D}",
            templateID: "ghost_h_2",
            artFilename: "card_ghost_h_2"
        )
    }

    /// H. Consciência — revela intents + dano em área mas custa MUITO moral.
    /// Injetada antes do boss Ato 3.
    public static func ghostH3() -> Card {
        Card(
            name: "H. Consciência",
            cost: 2,
            type: .corrupcao,
            effects: [
                .damageSelfMoral(5),
                .revealAllIntents,
                .damageAll(8),
            ],
            flavor: "\u{201C}Você não devia saber isso.\u{201D}",
            templateID: "ghost_h_3",
            artFilename: "card_ghost_h_3"
        )
    }

    /// Retorna uma factory de carta extra pelo templateID. Nil se não conhecido.
    /// Usado por `buildDeck` pra expandir o deck com extras do PlayerDeck.
    public static func extraCardTemplate(for templateID: String) -> Card? {
        switch templateID {
        case "gas_release":      return gasRelease()
        case "silent_reserve":   return silentReserve()
        case "whisper_truth":    return whisperTruth()
        case "attentive_listen": return attentiveListen()
        case "silenced_witness": return testemunhaSilenciada()
        case "conscience":       return consciencia()
        case "ghost_h_1":        return ghostH1()
        case "ghost_h_2":        return ghostH2()
        case "ghost_h_3":        return ghostH3()
        default:                 return nil
        }
    }
}
