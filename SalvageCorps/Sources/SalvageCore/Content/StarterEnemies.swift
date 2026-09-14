import Foundation

/// Inimigos iniciais (Ato 1) para o MVP.
///
/// Nomes de artes referenciam arquivos em `Art/` do target iOS.
public enum StarterEnemies {

    public static func recrutaAlemao() -> Enemy {
        Enemy(
            name: "Recruta Alemão",
            maxHP: 20,
            intentPattern: IntentPattern([
                .attack(damage: 5),
            ]),
            flavor: "Um garoto que só queria voltar pra casa.",
            artFilename: "enemy_recruta_alemao"
        )
    }

    public static func metralhadoraAninhada() -> Enemy {
        Enemy(
            name: "Metralhadora Aninhada",
            maxHP: 35,
            intentPattern: IntentPattern([
                .defend(block: 8),
                .multiAttack(damage: 4, hits: 3),
            ]),
            flavor: "Aninhada. Paciente. Faminta.",
            artFilename: "enemy_metralhadora"
        )
    }

    public static func recrutaTraumatizado() -> Enemy {
        Enemy(
            name: "Recruta Traumatizado",
            maxHP: 25,
            intentPattern: IntentPattern([
                .attackAndMoral(damage: 4, moralDamage: 3),
            ]),
            flavor: "Ele não para de rir.",
            artFilename: "enemy_traumatizado"
        )
    }

    // MARK: - Boss do Ato 1 — Hauptmann Krüger (3 fases)

    /// Boss narrativo do Ato 1. 3 fases:
    /// - **Fase 1 (100-67% HP)**: O Comandante — oficial competente, ataques físicos
    /// - **Fase 2 (66-34% HP)**: A Testemunha — começa a ver o mesmo que Edmund, ataca Moral
    /// - **Fase 3 (33-0% HP)**: O Corrompido — consumido pelo que viu, ataques massivos
    public static func oficialAlemao() -> Enemy {
        Enemy(
            name: "Hauptmann Krüger",
            maxHP: 80,
            intentPattern: IntentPattern([  // fallback (não usado — phasePatterns preenchido)
                .attack(damage: 8),
            ]),
            flavor: "\u{201C}Halt! Ergeben Sie sich!\u{201D}",
            artFilename: "boss_oficial_alemao",
            phasePatterns: [
                // ----- Fase 1: O Comandante -----
                IntentPattern([
                    .attack(damage: 8),
                    .defend(block: 6),
                    .attack(damage: 10),
                    .attack(damage: 8),
                ]),
                // ----- Fase 2: A Testemunha -----
                // Muda pra ataques de moral. Ele viu algo, começa a atacar sua sanidade.
                IntentPattern([
                    .moralAttack(damage: 6),
                    .attackAndMoral(damage: 4, moralDamage: 4),
                    .moralAttack(damage: 8),
                    .attack(damage: 6),
                ]),
                // ----- Fase 3: O Corrompido -----
                // Ataques massivos. Nada mais faz sentido pra ele.
                IntentPattern([
                    .multiAttack(damage: 6, hits: 2),
                    .attackAndMoral(damage: 8, moralDamage: 4),
                    .attack(damage: 14),
                ]),
            ],
            phaseThresholds: [0.66, 0.33],
            phaseIntros: [
                "",  // fase 0 (início) — não usa
                "Krüger para. Olha por cima do seu ombro. Diz algo em alemão que você quase entende. Depois muda de língua.",
                "Ele começa a falar numa língua que você não conhece — mas reconhece. É a mesma dos seus sonhos. K̶ę̷n̶o̷m̸a̸.",
            ]
        )
    }

    // Encontros pré-fabricados para testes

    public static func encounterEasy() -> [Enemy] {
        [recrutaAlemao(), recrutaAlemao()]
    }

    public static func encounterMedium() -> [Enemy] {
        [recrutaAlemao(), metralhadoraAninhada()]
    }

    public static func encounterHard() -> [Enemy] {
        [recrutaAlemao(), metralhadoraAninhada(), recrutaTraumatizado()]
    }

    public static func encounterBoss() -> [Enemy] {
        [oficialAlemao()]
    }

    // ========================================================================
    // MARK: - ATO 2: inimigos + encounters
    // ========================================================================

    /// Gas Wraith — entidade etérea envolvida em cloud de gás mostarda.
    /// Ataca principalmente Moral, difícil de mirar (HP menor, block em bursts).
    /// Intent OCULTA por default (fog of war Ato 2).
    public static func gasWraith() -> Enemy {
        Enemy(
            name: "Espectro de Gás",
            maxHP: 28,
            intentPattern: IntentPattern([
                .moralAttack(damage: 5),
                .attack(damage: 4),
                .moralAttack(damage: 7),
            ]),
            flavor: "Você não sabe se está vendo ou lembrando.",
            artFilename: "enemy_gas_wraith",
            intentHiddenByDefault: true
        )
    }

    /// Trench Ghoul — soldado morto corrompido. Alto HP, alto dano físico.
    /// Intent OCULTA por default.
    public static func trenchGhoul() -> Enemy {
        Enemy(
            name: "Trench Ghoul",
            maxHP: 42,
            intentPattern: IntentPattern([
                .attack(damage: 8),
                .defend(block: 6),
                .attack(damage: 11),
                .attack(damage: 8),
            ]),
            flavor: "Ele ainda usa o capacete britânico.",
            artFilename: "enemy_trench_ghoul",
            intentHiddenByDefault: true
        )
    }

    /// Barbed Cultist — humano voluntariamente corrompido (elite Ato 2).
    /// Ataques compostos (dano + moral), tanky. Intent OCULTA.
    public static func barbedCultist() -> Enemy {
        Enemy(
            name: "Cultista Espinhoso",
            maxHP: 55,
            intentPattern: IntentPattern([
                .attackAndMoral(damage: 6, moralDamage: 4),
                .defend(block: 8),
                .multiAttack(damage: 3, hits: 3),
                .attackAndMoral(damage: 5, moralDamage: 5),
            ]),
            flavor: "\u{201C}Ele nos chamou pelo nome.\u{201D}",
            artFilename: "enemy_barbed_cultist",
            intentHiddenByDefault: true
        )
    }

    // MARK: - Boss do Ato 2 — Barbed Apostle (2 fases)

    /// Barbed Apostle — sacerdote humano que se tornou cerimonial pro Corps.
    /// Boss é sempre VISÍVEL — a ameaça precisa ser lida claramente.
    ///
    /// **Fase 1 — O Sacerdote (100-50% HP)**: ataques compostos, defesa esporádica
    /// **Fase 2 — O Corrompido (50-0% HP)**: multiattacks massivos, sem defesa
    public static func barbedApostle() -> Enemy {
        Enemy(
            name: "Apóstolo Espinhoso",
            maxHP: 100,
            intentPattern: IntentPattern([  // fallback
                .attack(damage: 10),
            ]),
            flavor: "\u{201C}Vocês trouxeram a chave. Nem sabem que trouxeram.\u{201D}",
            artFilename: "boss_barbed_apostle",
            phasePatterns: [
                // ----- Fase 1: O Sacerdote -----
                IntentPattern([
                    .attack(damage: 10),
                    .defend(block: 8),
                    .moralAttack(damage: 6),
                    .attackAndMoral(damage: 8, moralDamage: 4),
                ]),
                // ----- Fase 2: O Corrompido -----
                IntentPattern([
                    .multiAttack(damage: 6, hits: 3),
                    .attackAndMoral(damage: 10, moralDamage: 6),
                    .attack(damage: 16),
                ]),
            ],
            phaseThresholds: [0.5],
            phaseIntros: [
                "",  // fase 0 (início) — não usa
                "As espinhas atravessam a batina dele por dentro. Ele sorri como se agradecesse. \u{201C}Agora vocês entendem.\u{201D}",
            ]
        )
    }

    // Encontros Ato 2

    public static func act2EncounterEasy() -> [Enemy] {
        [gasWraith(), gasWraith()]
    }

    public static func act2EncounterMedium() -> [Enemy] {
        [gasWraith(), trenchGhoul()]
    }

    public static func act2EncounterHard() -> [Enemy] {
        [barbedCultist(), gasWraith()]
    }

    public static func act2EncounterBoss() -> [Enemy] {
        [barbedApostle()]
    }

    // ========================================================================
    // MARK: - ATO 3: inimigos + encounters
    // ========================================================================

    /// Espectro de Granadeiro — soldado morto em Loos que ainda joga granadas.
    /// Multi-attack agressivo, HP médio. Intent OCULTA (fog of war continua Ato 3).
    /// Nerfado no rebalance: HP 35→28, dano ajustado pra caber no perfil do jogador.
    public static func spectralGrenadier() -> Enemy {
        Enemy(
            name: "Espectro de Granadeiro",
            maxHP: 28,
            intentPattern: IntentPattern([
                .multiAttack(damage: 4, hits: 2),
                .attack(damage: 9),
                .defend(block: 5),
                .multiAttack(damage: 3, hits: 3),
            ]),
            flavor: "Você o matou em Loos. Ele ainda está aqui.",
            artFilename: "enemy_trench_ghoul",  // fallback — reusa ghoul, sem art própria
            intentHiddenByDefault: true
        )
    }

    /// Boca que Sussurra — entidade pequena com dano psíquico.
    /// Baixo HP mas se ignorar sangra Moral. Nerfada no rebalance: dano moral
    /// reduzido de 8/6/10 pra 5/4/7 (encounter Easy tinha 2 dessas = 16 moral/turno,
    /// era brutal em combinação com o dano físico dos outros).
    public static func whisperMouth() -> Enemy {
        Enemy(
            name: "Boca que Sussurra",
            maxHP: 18,
            intentPattern: IntentPattern([
                .moralAttack(damage: 5),
                .moralAttack(damage: 4),
                .moralAttack(damage: 7),
            ]),
            flavor: "Diz seu nome. Depois o de Henry.",
            artFilename: "enemy_gas_wraith",  // fallback — reusa wraith
            intentHiddenByDefault: true
        )
    }

    // MARK: - Boss do Ato 3 — General's Ghost (4 fases)

    /// General's Ghost — última ameaça. 4 fases narrativamente crescentes.
    /// Boss VISÍVEL — dread é linha central da última luta.
    ///
    /// **Fase 1 — O General (100-75% HP)**: comportamento militar profissional
    /// **Fase 2 — O Fantasma (75-50% HP)**: começa a translucir, ataques psíquicos
    /// **Fase 3 — Os Ecos (50-25% HP)**: soldados atrás dele avançam
    /// **Fase 4 — O Espelho (25-0% HP)**: revela o rosto (é o de Edmund)
    public static func generalsGhost() -> Enemy {
        Enemy(
            name: "General's Ghost",
            maxHP: 105,
            intentPattern: IntentPattern([  // fallback (não usado)
                .attack(damage: 10),
            ]),
            flavor: "\u{201C}Você está atrasado, tenente.\u{201D}",
            artFilename: "boss_generals_ghost",
            phasePatterns: [
                // ----- Fase 1: O General -----
                // Nerfado no rebalance: dano proporcional ao Ato 2 Boss.
                IntentPattern([
                    .attack(damage: 10),
                    .defend(block: 10),
                    .attack(damage: 11),
                    .multiAttack(damage: 3, hits: 3),
                ]),
                // ----- Fase 2: O Fantasma -----
                // Ataques psíquicos + físicos misturados. Translúcido.
                IntentPattern([
                    .attack(damage: 8),
                    .moralAttack(damage: 6),
                    .attackAndMoral(damage: 6, moralDamage: 4),
                    .defend(block: 8),
                ]),
                // ----- Fase 3: Os Ecos -----
                // Vozes atrás dele — ataques multi + moral pesado
                IntentPattern([
                    .multiAttack(damage: 5, hits: 3),
                    .moralAttack(damage: 7),
                    .attack(damage: 12),
                ]),
                // ----- Fase 4: O Espelho -----
                // Ataques significativos. Última fase — mas com margem pra vencer.
                IntentPattern([
                    .attack(damage: 15),
                    .attackAndMoral(damage: 8, moralDamage: 6),
                    .multiAttack(damage: 6, hits: 2),
                ]),
            ],
            phaseThresholds: [0.75, 0.50, 0.25],
            phaseIntros: [
                "",  // fase 0 (início)
                "O uniforme dele começa a translucir. Você vê ATRAVÉS dele — soldados alinhados até o horizonte, todos parados, todos esperando ordem.",
                "Os soldados atrás dele avançam um passo em uníssono. Todos falam ao mesmo tempo. Você reconhece uma das vozes. É a de Henry.",
                "Ele para de atacar. Se vira lentamente. Você vê o rosto dele pela primeira vez.\n\nÉ o seu.",
            ]
        )
    }

    // Encontros Ato 3

    public static func act3EncounterEasy() -> [Enemy] {
        [whisperMouth(), whisperMouth()]
    }

    public static func act3EncounterMedium() -> [Enemy] {
        [spectralGrenadier(), whisperMouth()]
    }

    public static func act3EncounterHard() -> [Enemy] {
        // Rebalance: era [granadeiro, granadeiro, whisper] — 3 inimigos + 17 dmg
        // /turno + 8 moral era brutal em elite. Agora [granadeiro, whisper], que
        // ainda pune mas dá margem de recuperação.
        [spectralGrenadier(), whisperMouth()]
    }

    public static func act3EncounterBoss() -> [Enemy] {
        [generalsGhost()]
    }
}
