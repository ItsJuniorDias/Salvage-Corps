import Foundation

/// Catálogo central de upgrades disponíveis.
///
/// Cada carta base (identificada por `templateID`) tem 2 caminhos:
/// - Path A: geralmente "mais poder" (números maiores)
/// - Path B: geralmente "mais utilidade" (draw, redução de custo, status effects)
///
/// Adicionar novo upgrade = adicionar case novo aqui + garantir templateID
/// da carta bater com key esperada.
public enum UpgradeCatalog {

    /// Retorna as 2 opções de upgrade pra um template. Vazio se não conhecido.
    public static func upgrades(for templateID: String) -> [CardUpgrade] {
        switch templateID {
        case "order_shoot":         return [orderShootA, orderShootB]
        case "close_formation":     return [closeFormationA, closeFormationB]
        case "push_forward":        return [pushForwardA, pushForwardB]
        case "reinforce_moral":     return [reinforceMoralA, reinforceMoralB]
        case "order_shout":         return [orderShoutA, orderShoutB]
        case "rationalize":         return [rationalizeA, rationalizeB]
        case "counter_attack":      return [counterAttackA, counterAttackB]
        case "order_retreat":       return [orderRetreatA, orderRetreatB]
        case "silenced_witness":    return [silencedWitnessA, silencedWitnessB]
        case "conscience":          return [conscienceA, conscienceB]
        // Ato 2 (cartas obtidas via eventos)
        case "gas_release":         return [gasReleaseA, gasReleaseB]
        case "silent_reserve":      return [silentReserveA, silentReserveB]
        case "whisper_truth":       return [whisperTruthA, whisperTruthB]
        case "attentive_listen":    return [attentiveListenA, attentiveListenB]
        default:                    return []
        }
    }

    // MARK: - Order: Shoot (base: 1 cost, 6 damage single-enemy)

    static let orderShootA = CardUpgrade(
        id: "order_shoot_a",
        name: "Fogo Concentrado",
        shortDescription: "9 de dano em 1 alvo",
        flavorText: "Mira, aperta, mira de novo.",
        effects: [.damage(9)]
    )
    static let orderShootB = CardUpgrade(
        id: "order_shoot_b",
        name: "Ordem: Fuzilar",
        shortDescription: "6 dano + Medo 1",
        flavorText: "Não pra matar. Pra avisar.",
        effects: [.damage(6), .applyStatus(.fear, stacks: 1)]
    )

    // MARK: - Close Formation (base: 1 cost, +5 block)

    static let closeFormationA = CardUpgrade(
        id: "close_formation_a",
        name: "Formação Rígida",
        shortDescription: "+8 de bloqueio",
        flavorText: "Escudos travados. Ninguém passa.",
        effects: [.gainBlock(8)]
    )
    static let closeFormationB = CardUpgrade(
        id: "close_formation_b",
        name: "Formação Coordenada",
        shortDescription: "+5 bloqueio + compra 1 carta",
        flavorText: "Um sinal. Cinco reações.",
        effects: [.gainBlock(5), .draw(1)]
    )

    // MARK: - Push Forward (base: 1 cost, skipNextTurn)

    static let pushForwardA = CardUpgrade(
        id: "push_forward_a",
        name: "Empurrar com Força",
        shortDescription: "Atordoa + 3 de dano",
        flavorText: "Baioneta primeiro. Perguntas depois.",
        effects: [.damage(3), .skipNextTurn]
    )
    static let pushForwardB = CardUpgrade(
        id: "push_forward_b",
        name: "Empurrar com Terror",
        shortDescription: "Atordoa + Medo 2",
        flavorText: "O que ele viu no seu rosto, ele nunca vai esquecer.",
        effects: [.skipNextTurn, .applyStatus(.fear, stacks: 2)]
    )

    // MARK: - Reinforce Moral (base: 1 cost, +5 moral)

    static let reinforceMoralA = CardUpgrade(
        id: "reinforce_moral_a",
        name: "Palavras Firmes",
        shortDescription: "+8 de moral",
        flavorText: "Você acreditou. Ele acreditou. Foi o bastante.",
        effects: [.gainMoral(8)]
    )
    static let reinforceMoralB = CardUpgrade(
        id: "reinforce_moral_b",
        name: "Reforçar em Alto e Bom Som",
        shortDescription: "+5 moral + compra 1 carta",
        flavorText: "PELO REI E PELA PÁTRIA! Grita duas vezes.",
        effects: [.gainMoral(5), .draw(1)]
    )

    // MARK: - Order: Shout (base: 2 cost, damageAll 4 + fear all 2)

    static let orderShoutA = CardUpgrade(
        id: "order_shout_a",
        name: "Grito Devastador",
        shortDescription: "7 dano em todos + Medo 2 em todos",
        flavorText: "SEGURA A LINHA!!!",
        effects: [
            .damageAll(7),
            .applyStatusAll(.fear, stacks: 2)
        ]
    )
    static let orderShoutB = CardUpgrade(
        id: "order_shout_b",
        name: "Grito Terrificante",
        shortDescription: "4 dano em todos + Medo 4 em todos",
        flavorText: "O grito não é ordem. É aviso.",
        effects: [
            .damageAll(4),
            .applyStatusAll(.fear, stacks: 4)
        ]
    )

    // MARK: - Rationalize (base: 0 cost, exile + 3 moral)

    static let rationalizeA = CardUpgrade(
        id: "rationalize_a",
        name: "Racionalizar a Fundo",
        shortDescription: "Exila 1 carta + 5 moral",
        flavorText: "Não. Foi necessário. Foi correto. Foi.",
        effects: [.exhaustChosenFromHand, .gainMoral(5)]
    )
    static let rationalizeB = CardUpgrade(
        id: "rationalize_b",
        name: "Racionalizar Rapidamente",
        shortDescription: "Exila 1 carta + 3 moral + compra 1",
        flavorText: "Segue em frente. Segue em frente. Segue.",
        effects: [.exhaustChosenFromHand, .gainMoral(3), .draw(1)]
    )

    // MARK: - Counter Attack (base: 1 cost, 3 damage + 3 block)

    static let counterAttackA = CardUpgrade(
        id: "counter_attack_a",
        name: "Contra-Ataque Feroz",
        shortDescription: "6 dano + 3 bloqueio",
        flavorText: "Ele bateu primeiro. O último a bater vence.",
        effects: [.damage(6), .gainBlock(3)]
    )
    static let counterAttackB = CardUpgrade(
        id: "counter_attack_b",
        name: "Contra-Ataque Defensivo",
        shortDescription: "3 dano + 6 bloqueio",
        flavorText: "Um passo atrás. Dois pra frente.",
        effects: [.damage(3), .gainBlock(6)]
    )

    // MARK: - Order: Retreat (base: 2 cost, +8 block)

    static let orderRetreatA = CardUpgrade(
        id: "order_retreat_a",
        name: "Recuo Tático",
        shortDescription: "+12 de bloqueio",
        flavorText: "Recuar não é fraqueza. É trigonometria.",
        effects: [.gainBlock(12)]
    )
    static let orderRetreatB = CardUpgrade(
        id: "order_retreat_b",
        name: "Recuo Estratégico",
        shortDescription: "+8 bloqueio · custa apenas 1",
        flavorText: "Aprenda quando correr. Aprenda antes.",
        cost: 1,
        effects: [.gainBlock(8)]
    )

    // MARK: - Silenced Witness (base: 0 cost, 4 damage, corrupcao)

    static let silencedWitnessA = CardUpgrade(
        id: "silenced_witness_a",
        name: "Testemunha Enterrada",
        shortDescription: "7 de dano em 1 alvo",
        flavorText: "Pá. Pá. Pá. Terra por cima. Termina.",
        effects: [.damage(7)]
    )
    static let silencedWitnessB = CardUpgrade(
        id: "silenced_witness_b",
        name: "Testemunha Sacrificada",
        shortDescription: "4 dano + 3 moral",
        flavorText: "Uma testemunha a menos. Uma mentira a mais.",
        effects: [.damage(4), .gainMoral(3)]
    )

    // MARK: - Conscience (base: 1 cost, +5 moral, retain)

    static let conscienceA = CardUpgrade(
        id: "conscience_a",
        name: "Consciência Persistente",
        shortDescription: "+8 moral · fica na mão",
        flavorText: "Ela não vai a lugar nenhum.",
        effects: [.gainMoral(8)],
        retain: true
    )
    static let conscienceB = CardUpgrade(
        id: "conscience_b",
        name: "Consciência Compartilhada",
        shortDescription: "+5 moral + compra 1 · fica na mão",
        flavorText: "Alguém precisa carregar isso. Não sozinho.",
        effects: [.gainMoral(5), .draw(1)],
        retain: true
    )

    // MARK: - Gas Release (base: 2 cost, damageAll 3 + fear all 2)

    static let gasReleaseA = CardUpgrade(
        id: "gas_release_a",
        name: "Gás Concentrado",
        shortDescription: "5 em todos + Medo 2 em todos",
        flavorText: "Válvula toda aberta.",
        effects: [
            .damageAll(5),
            .applyStatusAll(.fear, stacks: 2)
        ]
    )
    static let gasReleaseB = CardUpgrade(
        id: "gas_release_b",
        name: "Gás Persistente",
        shortDescription: "3 em todos + Medo 4 em todos",
        flavorText: "A nuvem não vai embora.",
        effects: [
            .damageAll(3),
            .applyStatusAll(.fear, stacks: 4)
        ]
    )

    // MARK: - Silent Reserve (base: 0 cost, +4 block, retain)

    static let silentReserveA = CardUpgrade(
        id: "silent_reserve_a",
        name: "Reserva Ampla",
        shortDescription: "+7 bloqueio · fica na mão",
        flavorText: "Cavou fundo antes.",
        effects: [.gainBlock(7)],
        retain: true
    )
    static let silentReserveB = CardUpgrade(
        id: "silent_reserve_b",
        name: "Reserva Distribuída",
        shortDescription: "+4 bloqueio + compra 1 · fica na mão",
        flavorText: "Cada mão que carrega uma pá.",
        effects: [.gainBlock(4), .draw(1)],
        retain: true
    )

    // MARK: - Whisper Truth (base: 1 cost, -2 moral self + damage 12)

    static let whisperTruthA = CardUpgrade(
        id: "whisper_truth_a",
        name: "Verdade Devastadora",
        shortDescription: "-2 moral · 16 dano em 1 alvo",
        flavorText: "Chamou pelo nome verdadeiro.",
        effects: [
            .damageSelfMoral(2),
            .damage(16)
        ]
    )
    static let whisperTruthB = CardUpgrade(
        id: "whisper_truth_b",
        name: "Verdade Compartilhada",
        shortDescription: "-3 moral · 12 dano + compra 2",
        flavorText: "Todos ouviram junto. Todos pagaram junto.",
        effects: [
            .damageSelfMoral(3),
            .damage(12),
            .draw(2)
        ]
    )

    // MARK: - Attentive Listen (base: 0 cost, revealAllIntents, retain)

    static let attentiveListenA = CardUpgrade(
        id: "attentive_listen_a",
        name: "Escuta Prolongada",
        shortDescription: "Revela intents + compra 1 · fica na mão",
        flavorText: "Escuta e usa o que ouve.",
        effects: [.revealAllIntents, .draw(1)],
        retain: true
    )
    static let attentiveListenB = CardUpgrade(
        id: "attentive_listen_b",
        name: "Escuta Silenciosa",
        shortDescription: "Revela intents + 3 bloqueio · fica na mão",
        flavorText: "Escuta enquanto se protege.",
        effects: [.revealAllIntents, .gainBlock(3)],
        retain: true
    )
}
