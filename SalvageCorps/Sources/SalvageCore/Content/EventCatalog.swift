import Foundation

/// Catálogo central de eventos narrativos.
///
/// Estrutura: 1 evento FIXED por narrativeID (aparece em posição específica
/// do mapa) + N eventos PROCEDURAIS (rotativos em `.event` nodes sem ID).
///
/// **i18n**: pools embedded pt-BR são usadas por default. App-side pode chamar
/// `EventCatalog.setOverride(fixed:procedural:)` na inicialização pra injetar
/// versões traduzidas carregadas de JSON — típico pra localização en/es.
public enum EventCatalog {

    /// Override injetado pelo app-side. Se nil, usa embedded pt-BR.
    private static var overrideFixed: [GameEvent]? = nil
    private static var overrideProcedural: [GameEvent]? = nil

    /// Injeta pools traduzidas. Chame no startup do app depois de decidir idioma.
    /// Passar `nil` volta pro embedded pt-BR.
    public static func setOverride(fixed: [GameEvent]?, procedural: [GameEvent]?) {
        overrideFixed = fixed
        overrideProcedural = procedural
    }

    /// Pools ativas — override se disponível, senão embedded.
    private static var activeFixed: [GameEvent]     { overrideFixed ?? fixedEvents }
    private static var activeProcedural: [GameEvent] { overrideProcedural ?? proceduralEvents }

    // ========================================================================
    // Lookup por narrativeID (fixed) ou pool procedural
    // ========================================================================

    /// Retorna o evento pra um narrativeID específico (fixed).
    public static func event(for narrativeID: String) -> GameEvent? {
        activeFixed.first { $0.narrativeID == narrativeID }
    }

    /// Escolhe um evento procedural determinístico pelo UUID do nó.
    public static func proceduralEvent(atNodeID nodeID: UUID, act: Int) -> GameEvent? {
        let pool = activeProcedural.filter { $0.act == act }
        guard !pool.isEmpty else { return nil }
        let seed = UInt64(bitPattern: Int64(nodeID.hashValue))
        var rng = SeededRandom(seed: seed == 0 ? 1 : seed)
        let idx = rng.int(in: 0...(pool.count - 1))
        return pool[idx]
    }

    /// Resolve o evento pra um nó de forma automática.
    /// Se node.narrativeID bate com um fixed, retorna esse. Senão procedural.
    public static func resolveEvent(for narrativeID: String?, nodeID: UUID, act: Int) -> GameEvent? {
        if let narrativeID, let fixed = event(for: narrativeID) {
            return fixed
        }
        return proceduralEvent(atNodeID: nodeID, act: act)
    }

    // ========================================================================
    // FIXED EVENTS
    // ========================================================================

    private static let fixedEvents: [GameEvent] = [
        petrovWarning,
        ashcroftRevelation,
        henryAppears,
        mirrorTest,
    ]

    /// Ato 1, coluna 2 — Sargento Petrov chama pra conversa fundadora.
    static let petrovWarning = GameEvent(
        id: "petrov_warning",
        act: 1,
        title: "Petrov Quer Falar",
        narrative: """
        Petrov te chama pra fora do abrigo. Ele tem um cigarro entre os dedos que \
        não acendeu. Não olha pra você quando fala.

        \u{201C}Tenente. Sobre a última operação. Preciso te contar uma coisa antes \
        que fique tarde.\u{201D}
        """,
        backgroundArt: "bg_trench",
        choices: [
            EventChoice(
                id: "listen",
                label: "Escutar até o fim",
                costHint: "+5 Moral",
                effects: [.gainMoral(5)],
                resultText: """
                Ele fala baixo, direto, sem drama. Kholm, 1915. Vinte e três homens, \
                três sobreviventes. Uma coisa que não era alemã. Uma coisa que \
                sussurrava em uma língua que ninguém aprendeu.

                Você não sabe se acredita, mas o alívio de saber que alguém antes \
                de você viu — que não está sozinho na loucura — vale mais que \
                qualquer explicação.
                """
            ),
            EventChoice(
                id: "reject",
                label: "Rejeitar o aviso",
                costHint: "-3 Moral · +5 Max HP",
                effects: [.gainMoral(-3), .gainMaxHP(5)],
                resultText: """
                Você corta ele: \u{201C}Sargento. Nós estamos numa guerra. Focamos \
                em coisas reais.\u{201D}

                Petrov assente devagar. Guarda o cigarro. Sai sem uma palavra.

                A rejeição custa alguma coisa em você. Mas o foco também fortalece \
                — se você não se permite acreditar em fantasmas, seu corpo aguenta \
                mais que os que acreditam.
                """
            ),
            EventChoice(
                id: "ask_brother",
                label: "Perguntar sobre o irmão dele",
                costHint: "+3 Moral · +3 Max Moral",
                effects: [.gainMoral(3), .gainMaxMoral(3)],
                resultText: """
                Você mudou de assunto. Ele te olha pela primeira vez.

                \u{201C}Fyodor. Enterrei com essas mãos. Vinte anos. Ele acreditava \
                em Deus, e no Tsar, e no fim eu acho que ele acreditou que eu ia \
                salvá-lo. Mas eu não salvei.\u{201D}

                O silêncio depois é longo. Nenhum dos dois sabe o que dizer. Mas \
                algo entre vocês fica diferente. Mais forte, talvez.
                """
            ),
        ],
        narrativeID: "petrov_warning"
    )

    // ========================================================================
    // PROCEDURAL EVENTS
    // ========================================================================

    private static let proceduralEvents: [GameEvent] = [
        woundedSoldier,
        abandonedSupplies,
        strangeDream,
        letterFromHome,
        anomalousLight,
        // Ato 2 procedurais
        facelessBody,
        voiceThatCalls,
        strangeVial,
        tornPage,
        petrovSleepwalking,
        strangeBanner,
        listeningPost,
        // Ato 3 procedurais
        emptyBarracks,
        deadRadio,
        homecomingLetter,
        henrysCoat,
        officerWithoutName,
        rearGuardOrders,
        ninePointedFlagAgain,
    ]

    static let woundedSoldier = GameEvent(
        id: "wounded_soldier",
        act: 1,
        title: "Um Ferido na Cratera",
        narrative: """
        Um soldado britânico, jovem, jaz numa cratera. Perna esmagada. Consciente \
        mas em choque. Não vai andar de novo. O QG está a três horas caminhando. \
        Ele te pergunta pelo nome da mãe dele. Você não sabe.
        """,
        choices: [
            EventChoice(
                id: "carry",
                label: "Carregar até o posto médico",
                costHint: "-5 HP · +8 Moral",
                effects: [.gainHP(-5), .gainMoral(8)],
                resultText: """
                Três horas depois, você o entrega ao médico. Ele ainda respirava. \
                Suas costas te odeiam agora. Mas você olhou pra você mesmo no \
                espelho da bacia da médica e reconheceu o rosto.
                """
            ),
            EventChoice(
                id: "leave",
                label: "Deixá-lo · Marcar posição no mapa",
                costHint: "-3 Moral",
                effects: [.gainMoral(-3)],
                resultText: """
                Você marca a posição. Vai enviar um esquadrão pra buscá-lo assim \
                que puder. Provavelmente vão chegar tarde.

                Você se convence de que é a decisão certa. Você se convence.
                """
            ),
            EventChoice(
                id: "mercy",
                label: "Terminar o sofrimento dele",
                costHint: "-10 Moral · +3 HP",
                effects: [.gainMoral(-10), .gainHP(3)],
                resultText: """
                Uma bala. Ele mal percebeu.

                Você economiza tempo. Você economiza suprimentos médicos que outros \
                vão precisar. Você faz aritmética que a guerra te obriga a fazer.

                Você guarda o revólver. Suas mãos não tremem. Isso é o que assusta.
                """
            ),
        ]
    )

    static let abandonedSupplies = GameEvent(
        id: "abandoned_supplies",
        act: 1,
        title: "Suprimentos Abandonados",
        narrative: """
        Um caixote virado no meio da trincheira. Rações, bandagens, um pouco de \
        rum. Sem etiqueta, sem sinal de quem deixou aqui. Sem sinal de por que \
        deixaram.
        """,
        choices: [
            EventChoice(
                id: "take_all",
                label: "Levar tudo",
                costHint: "+8 HP · +3 Moral",
                effects: [.gainHP(8), .gainMoral(3)],
                resultText: """
                Você enche a mochila. Come uma ração ali mesmo, bebe um gole de \
                rum. Guarda o resto pros próximos combates.

                Não pergunta de onde veio. Não é a hora.
                """
            ),
            EventChoice(
                id: "distribute",
                label: "Distribuir com a unidade",
                costHint: "+5 Max HP",
                effects: [.gainMaxHP(5)],
                resultText: """
                Você chama Wardell e Wren. Divide tudo em três porções iguais. \
                Alguém no seu esquadrão vai lembrar disso quando for hora de \
                cobrir suas costas.

                Você fica um pouco mais forte. Não pelo que comeu — pelo que \
                sabe agora.
                """
            ),
            EventChoice(
                id: "leave",
                label: "Não tocar em nada",
                costHint: "+5 Moral",
                effects: [.gainMoral(5)],
                resultText: """
                Coisas boas demais no lugar errado são armadilhas. Você já viu \
                isso antes.

                Você passa longe. Um sino silencioso na cabeça vai parando de \
                tocar conforme você caminha.
                """
            ),
        ]
    )

    static let strangeDream = GameEvent(
        id: "strange_dream",
        act: 1,
        title: "Um Sonho Estranho",
        narrative: """
        Você acorda com o gosto de sal marinho na boca. No sonho, você caminhava \
        por uma trincheira que não tinha fim, e todas as vozes eram a voz do seu \
        irmão. Todas dizendo palavras diferentes. Todas dizendo o mesmo nome.

        \u{201C}Edmund.\u{201D}
        """,
        choices: [
            EventChoice(
                id: "tell_wren",
                label: "Contar pra Wren pela manhã",
                costHint: "-3 Moral",
                effects: [.gainMoral(-3)],
                resultText: """
                Ela ouve sem interromper. Anota alguma coisa numa caderneta que \
                ela sempre carrega. Depois diz apenas: \u{201C}Já ouvi antes.\u{201D}

                Você quer perguntar de quem. Ela troca de assunto.
                """
            ),
            EventChoice(
                id: "journal",
                label: "Anotar no seu diário de campo",
                costHint: "+5 Moral",
                effects: [.gainMoral(5)],
                resultText: """
                A caneta ajuda. Você descreve tudo em detalhe. Data, hora, o gosto \
                do sal, o eco das vozes. Escrever isso te faz sentir que existe \
                uma barreira entre o sonho e você.

                A barreira é fina. Mas está lá.
                """
            ),
            EventChoice(
                id: "ignore",
                label: "Ignorar · voltar a dormir",
                costHint: "-5 Max Moral · +3 Max HP",
                effects: [.gainMaxMoral(-5), .gainMaxHP(3)],
                resultText: """
                Você fecha os olhos de novo. Força o sono. Se convence de que é \
                cansaço, fome, química de trincheira.

                Você dorme. Mas alguma coisa acorda com você e não vai embora \
                mais. Você aprende a carregá-la.
                """
            ),
        ]
    )

    static let letterFromHome = GameEvent(
        id: "letter_from_home",
        act: 1,
        title: "Carta de Casa",
        narrative: """
        A correspondência chegou. Um envelope com sua mãe escrito na letra dela. \
        Você reconhece antes mesmo de ler o remetente. A carta esteve em algum \
        navio, algum trem, alguma mochila enlameada. Levou seis semanas pra \
        chegar. Você não sabe o que ela quer dizer.
        """,
        choices: [
            EventChoice(
                id: "read",
                label: "Ler agora",
                costHint: "+12 Moral · -5 HP",
                effects: [.gainMoral(12), .gainHP(-5)],
                resultText: """
                Ela escreve sobre coisas pequenas. O jardim. A tia Margaret. Um \
                cachorro do vizinho. No fim, uma linha: \u{201C}Seu pai perguntou \
                de você ontem. Ele está bem, considerando.\u{201D}

                Você chora um pouco, sem querer. Depois volta pra guerra e leva \
                dois dias pra parar de pensar naquilo. Nesses dias, você não \
                está totalmente presente.
                """
            ),
            EventChoice(
                id: "later",
                label: "Guardar pra ler depois",
                costHint: "+3 Moral · +5 Max HP",
                effects: [.gainMoral(3), .gainMaxHP(5)],
                resultText: """
                Você põe a carta no bolso interno do casaco, encostada ao peito. \
                Vai ler quando estiver seguro. Se estiver seguro.

                Saber que ela existe é o bastante por enquanto. Você respira mais \
                fundo e pega o rifle.
                """
            ),
        ]
    )

    static let anomalousLight = GameEvent(
        id: "anomalous_light",
        act: 1,
        title: "Luz Anômala na Cratera",
        narrative: """
        Do outro lado do campo, uma luz que não deveria estar ali. Verde-azulada, \
        pulsando devagar como algo respirando. Não é iluminação alemã. Não é \
        artilharia. Não é nada que você tenha visto em três anos de guerra.

        Ninguém no seu esquadrão vê. Só você.
        """,
        choices: [
            EventChoice(
                id: "investigate",
                label: "Investigar sozinho",
                costHint: "-8 HP · +5 Max Moral",
                effects: [.gainHP(-8), .gainMaxMoral(5)],
                resultText: """
                Você caminha até a cratera. A luz não vem de nada — não há fonte, \
                não há chama, não há resíduo. Só a luz. Ela recua conforme você \
                se aproxima, como maré.

                Quando você chega no fundo, não há nada. Mas você sabe algo agora \
                que não sabia antes. Alguma verdade que não consegue nomear, mas \
                que carrega uma força própria.
                """
            ),
            EventChoice(
                id: "report",
                label: "Reportar ao QG",
                costHint: "+3 Moral",
                effects: [.gainMoral(3)],
                resultText: """
                Você anota coordenadas, hora, natureza do fenômeno. Envia o \
                relatório na próxima correspondência.

                Ninguém responde. Nenhuma equipe é enviada. Você segue em frente \
                com a sensação de ter cumprido seu dever, o que às vezes é o \
                suficiente.
                """
            ),
            EventChoice(
                id: "ignore",
                label: "Fingir que não viu",
                costHint: "-5 Max Moral · +8 HP",
                effects: [.gainMaxMoral(-5), .gainHP(8)],
                resultText: """
                Você vira o rosto. Continua a marcha com o esquadrão. Não fala \
                sobre isso naquela noite, nem na próxima, nem nunca.

                Seu corpo agradece. Sua mente também, mas de um jeito diferente \
                — como quando você tranca a porta de um cômodo que precisa ficar \
                trancado.
                """
            ),
        ]
    )

    // ========================================================================
    // MARK: - ATO 2 EVENTS
    // ========================================================================

    /// Ato 2, coluna 3 (fixed) — Ashcroft revela que sabia mais do que dizia.
    static let ashcroftRevelation = GameEvent(
        id: "ashcroft_revelation",
        act: 2,
        title: "Ashcroft, Enfim, Fala",
        narrative: """
        Ashcroft te pega sozinho depois do briefing. Ele não tem mais o sorriso de \
        acadêmico curioso que carregava no Ato I. Segura um manuscrito manchado \
        de terra.

        \u{201C}Vale. Você precisa saber. Eu recebi ordens de Whitehall antes de \
        vocês serem recrutados. Este não é o primeiro Salvage Corps. É o quinto. \
        Os quatro anteriores… desapareceram. Cada um. E cada um recebeu ordens \
        de encontrar exatamente o que vocês estão prestes a encontrar.\u{201D}
        """,
        backgroundArt: "bg_no_mans_land",
        choices: [
            EventChoice(
                id: "trust",
                label: "Confiar nele — pedir os livros",
                costHint: "+3 Moral · +5 Max HP · +Carta",
                effects: [
                    .gainMoral(3),
                    .gainMaxHP(5),
                    .addCard(templateID: "silent_reserve"),
                ],
                resultText: """
                Ashcroft te entrega três livros que ele carregava escondidos: \
                traduções latinas de textos gnósticos, notas de campo de um capitão \
                francês em 1871, e um diário do próprio Salvage Corps de 1876.

                Você lê tudo naquela noite. Não dorme. Mas quando amanhece, você \
                sabe o que está enfrentando. E saber tem um peso — mas também dá \
                estrutura. Você pode se preparar pra estrutura.

                Ashcroft também te ensina uma técnica antiga de reservar recursos \
                em silêncio, sem alarmar o inimigo. \u{201C}Vai precisar.\u{201D}
                """
            ),
            EventChoice(
                id: "reject",
                label: "Rejeitar — proibir Ashcroft de falar",
                costHint: "-5 Moral · +8 Max HP",
                effects: [.gainMoral(-5), .gainMaxHP(8)],
                resultText: """
                \u{201C}Capitão. Estamos numa missão militar. Não estamos investigando \
                sociedades ocultas. Guarde essas teorias.\u{201D}

                Ashcroft assente lentamente. Guarda os livros. Não fala com você \
                por três dias.

                A rejeição pesa. Mas o esforço de MANTER o foco fortalece você — \
                seu corpo aguenta mais quando sua mente não aceita alternativas.
                """
            ),
            EventChoice(
                id: "ask_kholm",
                label: "Perguntar se ele conhece \u{201C}Kholm\u{201D}",
                costHint: "-3 Moral · +5 Max Moral",
                effects: [.gainMoral(-3), .gainMaxMoral(5)],
                resultText: """
                Ashcroft para. Você vê no rosto dele que ele reconhece o nome. Ele \
                não pergunta como você sabe.

                \u{201C}Kholm foi 1915. Fronte Oriental. O Corps russo. Vinte e três \
                homens entraram. Três saíram. Um deles serve com você agora, não? \
                Sim. Eu sabia disso também.\u{201D}

                Você sente algo grande e frio se assentar na sua barriga. Não é \
                medo — é reconhecimento. De que está numa história muito maior do \
                que pensava. E que é hora de suportar essa história inteira.
                """
            ),
        ],
        narrativeID: "ashcroft_revelation"
    )

    // MARK: - Ato 2 procedurais

    static let facelessBody = GameEvent(
        id: "faceless_body",
        act: 2,
        title: "Corpo Sem Rosto",
        narrative: """
        Um corpo britânico numa cratera. Uniforme intacto, identificação intacta \
        — \u{201C}Cabo J. Hardy, 12º Regimento\u{201D}. Mas onde deveria estar o \
        rosto, há apenas pele lisa, contínua, como se nunca tivesse existido rosto \
        algum. Não é ferimento. Não é queimadura. É como se o rosto tivesse sido \
        POLIDO até deixar de ser.
        """,
        choices: [
            EventChoice(
                id: "cover",
                label: "Cobrir com terra e continuar",
                costHint: "-3 Moral",
                effects: [.gainMoral(-3)],
                resultText: """
                Você joga terra sobre ele. Não fala pra ninguém. O 12º Regimento \
                vai marcá-lo como MIA nas semanas seguintes. Alguém vai chorar por \
                ele em Yorkshire. Alguém vai perguntar o que aconteceu.

                Você segue em frente com uma imagem que não vai sair da cabeça por \
                muito tempo.
                """
            ),
            EventChoice(
                id: "study",
                label: "Examinar a pele com cuidado",
                costHint: "-5 HP · +5 Max Moral",
                effects: [.gainHP(-5), .gainMaxMoral(5)],
                resultText: """
                Você olha de perto. Toca. A pele é tépida. Ainda tem pulso fraco no \
                pescoço. Você não sabe o que essa criatura ainda É, mas sabe que \
                não é mais Hardy.

                Você usa a faca. Rápido. Enterra. Escreve o nome dele numa pedra.

                O trabalho custa. Mas você aprendeu algo essencial sobre o que \
                estão enfrentando. E esse tipo de conhecimento vale.
                """
            ),
            EventChoice(
                id: "check_id",
                label: "Guardar a identificação pra família",
                costHint: "+8 Moral · -3 Max HP",
                effects: [.gainMoral(8), .gainMaxHP(-3)],
                resultText: """
                Você guarda a placa de identificação. Escreve uma nota mental: J. \
                Hardy, 12º, encontrado nesta cratera, nesta data.

                Quando a guerra acabar — se acabar — você vai escrever pra família \
                dele. Vai mentir sobre o rosto. Vai dizer que foi rápido. Que ele \
                não sofreu.

                A promessa te fortalece por dentro. Mas você carrega peso extra \
                agora, na mochila e em outros lugares. Você aceita.
                """
            ),
        ]
    )

    static let voiceThatCalls = GameEvent(
        id: "voice_that_calls",
        act: 2,
        title: "Uma Voz no Vento",
        narrative: """
        Você está sozinho num posto de escuta noturno. Sua unidade dorme atrás de \
        você. O vento traz uma voz — feminina, distante, chamando um nome.

        \u{201C}Edmund.\u{201D}

        Você não reconhece a voz. Ninguém que conhece te chama pelo primeiro nome. \
        Nem sua mãe. Nem Henry chamava.
        """,
        choices: [
            EventChoice(
                id: "respond",
                label: "Responder \u{2014} baixinho",
                costHint: "-8 HP · +8 Max Moral",
                effects: [.gainHP(-8), .gainMaxMoral(8)],
                resultText: """
                \u{201C}Estou aqui\u{201D}, você sussurra.

                A voz para. Depois retorna, mais próxima. Depois mais próxima. \
                Você fica sentado durante uma hora sem se mover, e a voz não chega \
                nunca. Mas alguma coisa mudou no ar durante essa hora.

                Você não conta pra ninguém. Nunca. Mas você aprendeu que consegue \
                escutar. E escutar é uma habilidade que essa guerra vai exigir de \
                você.
                """
            ),
            EventChoice(
                id: "wake_unit",
                label: "Acordar a unidade",
                costHint: "-5 Moral",
                effects: [.gainMoral(-5)],
                resultText: """
                Você chama Wren e Petrov. Eles vêm rapidamente, armados. Vocês \
                escutam. A voz sumiu. O vento é só vento agora.

                Wren te olha com pena. Petrov não fala nada. Vocês voltam a dormir. \
                Você não dorme. Sente que os outros pensam menos de você agora — \
                talvez estejam certos.
                """
            ),
            EventChoice(
                id: "ignore",
                label: "Ignorar \u{2014} tampar os ouvidos",
                costHint: "-5 Max Moral · +5 HP",
                effects: [.gainMaxMoral(-5), .gainHP(5)],
                resultText: """
                Você tira o capacete, prende os dedos nos ouvidos. Fecha os olhos. \
                Espera que passe.

                Passa. O vento volta a ser só vento. Você sente uma calma estranha \
                — como se tivesse recusado uma proposta que não devia sequer ter \
                ouvido. Seu corpo relaxa.

                Mas alguma coisa em você fica menor essa noite. Você não sabe o \
                que era. Não vai saber nunca.
                """
            ),
        ]
    )

    // MARK: - Ato 2 procedurais com card rewards

    /// Frasco Estranho — dá "Liberação de Gás".
    static let strangeVial = GameEvent(
        id: "strange_vial",
        act: 2,
        title: "Frasco Estranho",
        narrative: """
        Numa mochila abandonada de um oficial alemão, você encontra um frasco de \
        vidro grosso, selado com cera vermelha. Dentro, um líquido âmbar que se \
        mexe sozinho quando você não olha diretamente. Um rótulo em alemão: \
        \u{201C}Für den letzten Einsatz\u{201D} — pra a última missão.
        """,
        choices: [
            EventChoice(
                id: "keep",
                label: "Levar o frasco",
                costHint: "+ Liberação de Gás · -3 Moral",
                effects: [
                    .addCard(templateID: "gas_release"),
                    .gainMoral(-3),
                ],
                resultText: """
                Você guarda o frasco na cintura, longe do rosto. Não pergunta o que \
                é. Não quer saber ainda. Sabe que uma hora vai usar. E que quando \
                usar, alguém do outro lado vai morrer de um jeito que ele não \
                merecia.

                Você guarda o frasco mesmo assim.
                """
            ),
            EventChoice(
                id: "smash",
                label: "Quebrar o frasco no chão",
                costHint: "+5 Moral · -3 HP",
                effects: [
                    .gainMoral(5),
                    .gainHP(-3),
                ],
                resultText: """
                Você joga o frasco contra uma pedra. O gás sobe amarelado. Você \
                puxa o pano do rosto rápido e recua. O gás fica ali por dois \
                minutos, depois some — como se tivesse voltado pra dentro.

                Sua garganta arde por um dia. Mas você dorme melhor essa noite.
                """
            ),
            EventChoice(
                id: "ignore",
                label: "Deixar onde estava",
                costHint: "sem efeito",
                effects: [],
                resultText: """
                Você recoloca o frasco na mochila do oficial morto. Segue em frente.

                Alguém, algum dia, vai encontrar de novo. Talvez faça uma escolha \
                diferente. Talvez a mesma. Você prefere não fazer parte da história.
                """
            ),
        ]
    )

    /// Diário Rasgado — dá "Sussurrar Verdade".
    static let tornPage = GameEvent(
        id: "torn_page",
        act: 2,
        title: "Uma Página Rasgada",
        narrative: """
        No fundo de uma trincheira alemã abandonada, você encontra páginas rasgadas \
        de um diário. A escrita é apressada, quase desesperada. A maior parte é \
        ilegível ou em alemão obscuro, mas uma linha se destaca, sublinhada três \
        vezes:

        \u{201C}Sag ihm seinen wahren Namen. Nur das trifft.\u{201D}
        \u{2014} Diga a ele seu nome verdadeiro. Só isso atinge.
        """,
        choices: [
            EventChoice(
                id: "study",
                label: "Estudar as páginas",
                costHint: "+ Sussurrar Verdade · -5 Moral",
                effects: [
                    .addCard(templateID: "whisper_truth"),
                    .gainMoral(-5),
                ],
                resultText: """
                Você guarda as páginas. Passa três noites decifrando. O que aprende \
                não pode ser desaprendido. Uma técnica antiga — chamar a coisa pelo \
                nome que ela nega ter, e assistir isso rachar por dentro.

                Você entende agora que essas coisas TÊM nomes verdadeiros. E que \
                dizê-los é uma arma que só quem sabe pode usar. Mas usar te custa \
                — porque agora você é uma das pessoas que sabem.
                """
            ),
            EventChoice(
                id: "burn",
                label: "Queimar as páginas",
                costHint: "+8 Moral · -3 Max Moral",
                effects: [
                    .gainMoral(8),
                    .gainMaxMoral(-3),
                ],
                resultText: """
                Você acende um fósforo. As páginas pegam fogo lentamente, como se \
                resistissem. Você segura até queimarem os seus dedos.

                Dorme melhor essa noite. Mas alguma coisa te acorda antes do \
                amanhecer — a sensação de que alguém do outro lado da guerra sabia \
                algo importante e agora ninguém mais sabe. E que isso pode ter \
                sido erro seu.
                """
            ),
            EventChoice(
                id: "pocket",
                label: "Guardar sem ler",
                costHint: "-3 HP",
                effects: [
                    .gainHP(-3),
                ],
                resultText: """
                Você dobra as páginas com cuidado. Guarda no fundo do casaco. Não \
                lê. Vai decidir depois. Depois nunca chega.

                As páginas vão te acompanhar pela guerra inteira. Você vai \
                esquecer delas às vezes. Vai lembrar delas em momentos ruins. Vai \
                nunca ler.

                Alguém carrega o peso do que sabe. Você carrega o peso do que \
                escolheu não saber.
                """
            ),
        ]
    )

    // MARK: - Ato 2 procedurais (batch 2)

    /// Petrov Sonâmbulo — Edmund encontra Petrov andando dormindo, falando russo.
    static let petrovSleepwalking = GameEvent(
        id: "petrov_sleepwalking",
        act: 2,
        title: "Petrov Fala Dormindo",
        narrative: """
        Três da manhã. Você acorda pra beber água e vê Petrov de pé no meio do \
        bivaque, olhos abertos, sem enxergar você. Ele fala em russo baixo, \
        contínuo, como quem reza. Você não entende as palavras. Uma se repete: \
        \u{201C}Fyodor\u{201D}.

        O nome do irmão dele.
        """,
        choices: [
            EventChoice(
                id: "wake",
                label: "Acordar Petrov com cuidado",
                costHint: "+5 Moral · -3 HP",
                effects: [.gainMoral(5), .gainHP(-3)],
                resultText: """
                Você toca o ombro dele. Petrov acorda com um choque, pega você \
                pelo casaco, olhos ainda vazios por um segundo. Depois foca. \
                Depois solta.

                \u{201C}Estava caminhando?\u{201D}
                \u{201C}Estava.\u{201D}
                \u{201C}Obrigado.\u{201D}

                Ele volta pra cama. Vocês nunca falam sobre isso de novo. Mas na \
                manhã seguinte, Petrov te oferece o primeiro chá — algo que ele \
                nunca fez antes.
                """
            ),
            EventChoice(
                id: "watch",
                label: "Observar em silêncio",
                costHint: "-3 Moral · +5 Max Moral",
                effects: [.gainMoral(-3), .gainMaxMoral(5)],
                resultText: """
                Você fica parado, escutando. Petrov continua falando por dez \
                minutos. Duas vezes olha diretamente pra você — através de você — \
                e diz algo que você quase entende. Não é russo essas duas frases. \
                É outra coisa.

                Depois ele volta pra cama sozinho. Você fica acordado até o \
                amanhecer, digerindo o que viu. Fica um pouco mais forte \
                mentalmente — mas nunca mais dorme igual nesse camp.
                """
            ),
            EventChoice(
                id: "note",
                label: "Anotar o que ele diz e dormir",
                costHint: "+3 Moral · +3 Max HP",
                effects: [.gainMoral(3), .gainMaxHP(3)],
                resultText: """
                Você pega o diário e transcreve foneticamente cada palavra. Não \
                sabe o que significa. Sabe que vai poder mostrar pra Ashcroft \
                depois. Isso te dá objetivo — e objetivo cansa menos que \
                confusão.

                Você dorme. Sonha com neve.
                """
            ),
        ]
    )

    /// Bandeira Estranha — posto alemão com símbolo desconhecido.
    static let strangeBanner = GameEvent(
        id: "strange_banner",
        act: 2,
        title: "Uma Bandeira que Não É",
        narrative: """
        Um posto alemão vazio. Não abandonado — vazio, como se todos tivessem \
        saído no meio de uma refeição. Sopa ainda morna. Café pela metade. Sobre \
        o rádio, uma bandeira que não é do Kaiser: um retângulo negro com um \
        símbolo em ouro fosco. Nove linhas partindo de um ponto central. Você \
        já viu esse símbolo antes — em um sonho que preferiu esquecer.
        """,
        choices: [
            EventChoice(
                id: "take",
                label: "Levar a bandeira dobrada",
                costHint: "-3 HP · +5 Max Moral",
                effects: [.gainHP(-3), .gainMaxMoral(5)],
                resultText: """
                Você dobra a bandeira em oito partes e enfia dentro da mochila. \
                O tecido é mais pesado do que devia ser pro tamanho. Você não \
                mostra pra ninguém do esquadrão.

                Nas noites seguintes, você a estuda em segredo. Não decifra o \
                símbolo. Mas aprende a olhar pra ele sem desviar — e isso é uma \
                habilidade que a guerra vai cobrar.
                """
            ),
            EventChoice(
                id: "burn",
                label: "Queimar no fogo do posto",
                costHint: "+5 Moral · -3 Max HP",
                effects: [.gainMoral(5), .gainMaxHP(-3)],
                resultText: """
                Você joga a bandeira no fogareiro alemão. O tecido não pega logo — \
                resiste três, quatro tentativas com fósforos. Quando finalmente \
                acende, a chama é verde-azulada por dois segundos, depois amarela.

                O símbolo se torce enquanto queima, como se tentasse formar outra \
                coisa antes de virar cinza. Você sai do posto rapidamente. Dorme \
                melhor essa noite, mas alguma coisa dentro de você fica mais \
                frágil pra sempre.
                """
            ),
            EventChoice(
                id: "photograph",
                label: "Desenhar no diário e deixar",
                costHint: "+3 Moral",
                effects: [.gainMoral(3)],
                resultText: """
                Você tira o diário e desenha o símbolo com precisão — nove linhas, \
                ângulos exatos, proporções corretas. Devolve a bandeira ao rádio \
                exatamente como estava. Sai do posto sem deixar rastro.

                Ashcroft vai olhar pro desenho depois e não vai dizer nada por um \
                longo minuto. Depois vai dizer: \u{201C}Isso é uma coisa muito \
                antiga, Vale. Muito.\u{201D} E vai mudar de assunto.
                """
            ),
        ]
    )

    /// Posto de Escuta Abandonado — dá "Escuta Atenta".
    static let listeningPost = GameEvent(
        id: "listening_post",
        act: 2,
        title: "Posto de Escuta Abandonado",
        narrative: """
        Você encontra um posto de escuta britânico esquecido — não destruído, \
        apenas esquecido. Cornetas de amplificação apontadas pro território \
        alemão. Anotações num caderno em código Morse manuscrito. E um manual \
        pequeno: \u{201C}Técnicas Silenciosas de Observação — Uso Interno\u{201D}.
        """,
        choices: [
            EventChoice(
                id: "study",
                label: "Estudar as técnicas",
                costHint: "+ Escuta Atenta · -3 Moral",
                effects: [
                    .addCard(templateID: "attentive_listen"),
                    .gainMoral(-3),
                ],
                resultText: """
                Você lê o manual duas vezes naquela noite. As técnicas são simples \
                mas exigem prática: colocar a orelha na terra, respirar em \
                sincronia com o vento, ouvir intervalos entre sons.

                Você aprende. E aprender custa: você começa a escutar coisas que \
                não quer escutar, também. Mas em combate, isso vai te salvar.
                """
            ),
            EventChoice(
                id: "supplies",
                label: "Pegar suprimentos e ignorar o manual",
                costHint: "+5 HP · +3 Moral",
                effects: [.gainHP(5), .gainMoral(3)],
                resultText: """
                Você enche os bolsos: rações, um cantil cheio, dois pacotes de \
                cigarros ingleses. Deixa o manual onde estava.

                Alguém, algum dia, vai encontrar de novo. Vai aprender o que \
                você recusou. Você prefere não fazer parte dessa cadeia.
                """
            ),
            EventChoice(
                id: "destroy",
                label: "Destruir tudo — não pode cair em mãos alemãs",
                costHint: "+3 Moral · -3 HP",
                effects: [.gainMoral(3), .gainHP(-3)],
                resultText: """
                Você quebra as cornetas com o coronha do rifle. Queima o caderno \
                de código. Rasga o manual em pedaços pequenos e enterra na lama.

                O trabalho custa esforço físico e leva quase uma hora. Mas você \
                sai do posto sabendo que fez a coisa certa pelo Corps. Isso vale \
                — ainda que ninguém saiba.
                """
            ),
        ]
    )

    // ========================================================================
    // MARK: - ATO 3 EVENTS
    // ========================================================================

    /// Ato 3, coluna 3 (fixed) — Henry aparece pela primeira vez à luz do dia.
    /// Aparição visível fora do camp: reconhecimento público.
    static let henryAppears = GameEvent(
        id: "henry_appears",
        act: 3,
        title: "Alguém Andando à Frente",
        narrative: """
        A coluna avança devagar pela estrada. Você vê uma silhueta trinta metros \
        à frente — um soldado britânico com capote comum, sem fila, sem cadência. \
        Você conhece aqueles ombros. Você enterrou aqueles ombros em 1914.

        \u{201C}Henry?\u{201D}

        Ele não vira. Continua andando no mesmo passo. Petrov, ao seu lado, olha \
        pra frente e depois pra você. Não pergunta o que você viu. Pergunta \
        apenas: \u{201C}Você conhece?\u{201D}
        """,
        backgroundArt: "bg_no_mans_land",
        choices: [
            EventChoice(
                id: "run_to_him",
                label: "Correr até ele",
                costHint: "-8 HP · +8 Max Moral",
                effects: [.gainHP(-8), .gainMaxMoral(8)],
                resultText: """
                Você quebra a formação. Corre. A estrada é mais longa do que \
                parecia. Cada passo dobra a distância. Quando você chega no ponto \
                onde ele estava, não há ninguém — só pegadas na lama, mesmo tamanho \
                das suas, mesmo padrão de bota.

                Você volta pra coluna arrastando as pernas. Petrov te dá o braço \
                nos últimos metros. Não faz perguntas. Você aprende, ali, que \
                consegue perseguir uma coisa sem esperar entendê-la — e esse tipo \
                de coragem vai pesar no fim.
                """
            ),
            EventChoice(
                id: "hold_position",
                label: "Segurar posição · não quebrar formação",
                costHint: "+5 Moral · +5 Max HP",
                effects: [.gainMoral(5), .gainMaxHP(5)],
                resultText: """
                Você aperta o rifle. Continua andando no ritmo da coluna. Os olhos \
                não saem da silhueta à frente. Ela caminha por mais dois minutos \
                e depois some numa curva — como se tivesse virado, ainda que a \
                estrada não tenha curva ali.

                Petrov não fala. Ninguém fala. Você segue com a unidade e algo \
                em você fica MAIS DURO — a disciplina de não obedecer o próprio \
                coração é uma armadura que a guerra recompensa.
                """
            ),
            EventChoice(
                id: "call_out",
                label: "Gritar o nome dele",
                costHint: "-5 Moral · +Sussurrar Verdade",
                effects: [
                    .gainMoral(-5),
                    .addCard(templateID: "whisper_truth"),
                ],
                resultText: """
                \u{201C}HENRY!\u{201D}

                Sua voz corta o silêncio da estrada. A silhueta para. Fica parada \
                um segundo inteiro. Depois vira devagar. Não é o rosto do Henry \
                — é o rosto DELE tentando ser o do Henry, e quase conseguindo, \
                errando por uma vírgula.

                Você aprende naquele instante que essas coisas têm nomes falsos \
                e que chamá-las pelo nome errado as ATRASA. Você agora sabe uma \
                arma. E ninguém devia saber essa arma.
                """
            ),
        ],
        narrativeID: "henry_appears"
    )

    /// Ato 3, coluna 5 (fixed) — o Teste do Espelho.
    /// Ashcroft monta uma prova pra descobrir se Edmund ainda é Edmund.
    static let mirrorTest = GameEvent(
        id: "mirror_test",
        act: 3,
        title: "O Teste do Espelho",
        narrative: """
        Ashcroft te chama pra dentro da tenda de comando. Sobre a mesa: um espelho \
        pequeno, quebrado, envolvido em pano preto. Uma vela. Um caderno aberto \
        numa página em latim.

        \u{201C}Vale. Isso não é ritual. É diagnóstico. Você vai olhar pro espelho \
        enquanto eu leio três linhas. Se o reflexo obedecer a você, você é você. \
        Se não obedecer — em qualquer momento — você me avisa, e eu resolvo. \
        Concorda?\u{201D}

        A voz dele está sem drama. É pior do que se estivesse assustado.
        """,
        backgroundArt: "bg_camp",
        choices: [
            EventChoice(
                id: "submit",
                label: "Aceitar o teste",
                costHint: "-3 HP · +8 Max Moral · +Escuta Atenta",
                effects: [
                    .gainHP(-3),
                    .gainMaxMoral(8),
                    .addCard(templateID: "attentive_listen"),
                ],
                resultText: """
                Você senta. Olha pro espelho. Ashcroft lê três linhas em latim, \
                devagar, sem inflexão. O reflexo pisca quando você pisca. Sorri \
                quando você sorri. Chora quando você não estava chorando — e você \
                percebe, um segundo depois, que estava.

                \u{201C}Você passou\u{201D}, Ashcroft diz baixinho. \u{201C}Mas \
                aprenda a escutar você mesmo. Vai precisar.\u{201D} Ele te ensina \
                uma técnica de escuta interna que dobra sua percepção em combate. \
                Custa — porque agora você OUVE também o que preferiria não ouvir.
                """
            ),
            EventChoice(
                id: "refuse",
                label: "Recusar · confiar no próprio julgamento",
                costHint: "+5 Moral · -5 Max Moral",
                effects: [.gainMoral(5), .gainMaxMoral(-5)],
                resultText: """
                \u{201C}Capitão. Eu sou eu. Não preciso de um espelho pra provar \
                isso. Se um dia eu não for mais eu, atire.\u{201D}

                Ashcroft te olha por muito tempo. Depois assente. Guarda o espelho \
                no pano preto sem fazer o teste. \u{201C}Tudo bem, Vale. Vou \
                confiar.\u{201D}

                Você sai da tenda com o peito mais leve — mas alguma coisa em você \
                sabe que recusar diagnóstico não cura a doença. Você ganha calma \
                agora e paga em teto depois.
                """
            ),
            EventChoice(
                id: "reverse",
                label: "Testar Ashcroft primeiro",
                costHint: "-3 Moral · +5 Max HP · +Reserva Silenciosa",
                effects: [
                    .gainMoral(-3),
                    .gainMaxHP(5),
                    .addCard(templateID: "silent_reserve"),
                ],
                resultText: """
                \u{201C}Capitão. Se o teste é bom, é bom pra nós dois. Você \
                primeiro.\u{201D}

                Ashcroft para. Sorri sem alegria. \u{201C}Justo.\u{201D} Ele senta. \
                Você lê as três linhas — ele te empurra o caderno com o dedo. O \
                reflexo dele piscA com atraso. Meio segundo. Ninguém que não \
                estivesse procurando iria notar.

                Vocês dois fingem que não viram. Terminam o teste. Ele te ensina \
                uma técnica de guardar recursos em silêncio pra usar depois — \
                \u{201C}vai precisar\u{201D}. Você sai da tenda sabendo alguma \
                coisa muito grande sobre Ashcroft. E vai carregar isso sozinho.
                """
            ),
        ],
        narrativeID: "mirror_test"
    )

    // MARK: - Ato 3 procedurais

    /// Barracas vazias — descoberta de um camp britânico abandonado no meio da retirada.
    static let emptyBarracks = GameEvent(
        id: "empty_barracks",
        act: 3,
        title: "Barracas Sem Ninguém",
        narrative: """
        Uma dúzia de barracas britânicas alinhadas, catres feitos, botas \
        organizadas ao pé de cada cama. Café ainda morno na cozinha comum. \
        Cartas metade escritas sobre a mesa. Nenhum corpo. Nenhum sinal de \
        luta. Apenas ausência — como se cada homem tivesse levantado no meio \
        de uma frase e caminhado pra fora.
        """,
        choices: [
            EventChoice(
                id: "read_letters",
                label: "Ler as cartas inacabadas",
                costHint: "-8 Moral · +5 Max Moral",
                effects: [.gainMoral(-8), .gainMaxMoral(5)],
                resultText: """
                Você lê seis, sete cartas. Todas param na mesma frase, quase \
                palavra por palavra: \u{201C}Mãe, tem uma coisa aqui que eu \
                preciso ir ver, mas quando eu voltar…\u{201D}

                Nenhuma foi terminada. Você guarda três — as três com endereço \
                completo. Uma promessa silenciosa de que se você sair dessa, \
                essas famílias vão saber que os filhos delas foram embora \
                escrevendo. Isso PESA. Mas peso também é ancoragem — você fica \
                mais firme depois.
                """
            ),
            EventChoice(
                id: "supplies",
                label: "Pegar suprimentos e sair rápido",
                costHint: "+8 HP · +3 Moral",
                effects: [.gainHP(8), .gainMoral(3)],
                resultText: """
                Você enche a mochila em três minutos: rações, bandagens, \
                bandolier de munição, um cantil cheio. Petrov faz o mesmo em \
                silêncio. Vocês saem pela mata sem olhar pra trás.

                A noite seguinte é a melhor noite de sono que você tem em \
                semanas. Você prefere não pensar em por quê.
                """
            ),
            EventChoice(
                id: "burn",
                label: "Queimar tudo · impedir que outra unidade caia aqui",
                costHint: "-3 HP · +8 Moral",
                effects: [.gainHP(-3), .gainMoral(8)],
                resultText: """
                Você espalha querosene das lamparinas. Petrov ajuda sem \
                perguntar. Vocês acendem as barracas uma por uma, a começar pela \
                cozinha. O fogo pega devagar — a lona úmida resiste — mas quando \
                pega, pega de vez.

                Vocês recuam pela mata. Olhando de longe, o acampamento fica \
                laranja contra o céu escuro. Nenhuma outra unidade britânica vai \
                dormir naqueles catres. Você fez o que a hierarquia não faria. \
                Isso te fortalece por dentro.
                """
            ),
        ]
    )

    /// Rádio Morto — voz numa frequência que já foi desativada.
    static let deadRadio = GameEvent(
        id: "dead_radio",
        act: 3,
        title: "Uma Voz na Frequência Morta",
        narrative: """
        O operador de rádio da unidade te chama de madrugada. Cara branca. Ele \
        te entrega o fone.

        \u{201C}Tenente. Essa frequência foi desativada em 1916. Não deveria \
        ter ninguém aqui. Escuta.\u{201D}

        Você põe o fone. Ruído estático. E depois, atravessando o ruído, uma \
        voz masculina lendo uma lista de nomes. A voz é a sua. A lista de \
        nomes são os homens do seu esquadrão — todos, na ordem em que estão \
        agora, dormindo lá fora.
        """,
        choices: [
            EventChoice(
                id: "keep_listening",
                label: "Continuar escutando até o fim da lista",
                costHint: "-10 Moral · +Escuta Atenta",
                effects: [
                    .gainMoral(-10),
                    .addCard(templateID: "attentive_listen"),
                ],
                resultText: """
                A voz — sua voz — lê 47 nomes. Wren. Petrov. Wardell. Ashcroft. \
                Cada praça. Cada cabo. Cada sargento. Ao fim, uma pausa, e \
                depois: \u{201C}Vale, Edmund.\u{201D}

                E o rádio se cala.

                Você fica sentado por vinte minutos sem se mover. O operador não \
                fala nada. Nunca comenta com ninguém. Você aprende algo naquela \
                madrugada sobre escutar sem interromper — uma habilidade que \
                agora É SUA, e que você não pediu.
                """
            ),
            EventChoice(
                id: "cut_off",
                label: "Desligar imediatamente · destruir o rádio",
                costHint: "+5 Moral · -3 Max HP",
                effects: [.gainMoral(5), .gainMaxHP(-3)],
                resultText: """
                Você arranca o fone. Corta os fios do rádio. Amassa a válvula \
                com o coldre. O operador olha, olha de novo, depois assente uma \
                única vez.

                \u{201C}Bom senso, senhor.\u{201D} Ele se levanta. Nunca mais \
                fala do assunto. Você dorme melhor essa noite — mas na semana \
                seguinte, começa a suar mais em combate, e você não sabe se é \
                cansaço, se é medo, se é o sistema começando a ceder.
                """
            ),
            EventChoice(
                id: "write_down",
                label: "Anotar cada nome que ouvir",
                costHint: "-5 HP · +5 Max Moral",
                effects: [.gainHP(-5), .gainMaxMoral(5)],
                resultText: """
                Você pega o caderno. Escreve cada nome à medida que a voz lê. \
                A voz é a sua. A caligrafia é a sua. O papel fica úmido — não \
                de suor, de outra coisa. Você não olha.

                Ao fim, você tem uma lista completa da sua unidade. Assinada, \
                por escrito, pela sua própria voz numa frequência morta. Você \
                guarda a folha. Vai olhar pra ela em silêncio nos próximos dias. \
                Vai aprender a suportar o próprio nome no fim da lista.
                """
            ),
        ]
    )

    /// Carta de Retorno — carta da mãe do Edmund escrita como se ele já tivesse voltado.
    static let homecomingLetter = GameEvent(
        id: "homecoming_letter",
        act: 3,
        title: "Ela Escreveu Como Se Já Fosse",
        narrative: """
        A correspondência chegou. Uma carta de sua mãe, na letra dela, com o \
        selo real.

        Ela escreve como se você já tivesse voltado.

        \u{201C}Meu filho, ontem no jantar você comeu duas porções da torta e eu \
        fiquei tão feliz. Você riu daquela história do Sr. Whitby. Está \
        engordando de novo. Está dormindo bem no seu quarto antigo. Amanhã eu \
        acordo cedo e faço pão pra você.\u{201D}

        A data no topo da carta é a de amanhã.
        """,
        choices: [
            EventChoice(
                id: "keep",
                label: "Guardar a carta perto do peito",
                costHint: "+10 Moral · -5 HP",
                effects: [.gainMoral(10), .gainHP(-5)],
                resultText: """
                Você dobra a carta em quatro. Enfia no bolso interno do casaco, \
                encostada ao coração. Vai reler várias vezes nos próximos dias.

                Alguma coisa em você começa a acreditar que já voltou, que essa \
                versão da guerra é o sonho, que a realidade é o pão da manhã \
                da mãe. Isso te dá força — e também te tira da defensiva. Custa. \
                Mas você aceita.
                """
            ),
            EventChoice(
                id: "burn",
                label: "Queimar sem reler",
                costHint: "-5 Moral · +8 Max HP",
                effects: [.gainMoral(-5), .gainMaxHP(8)],
                resultText: """
                Você acende um fósforo. A carta pega fogo lentamente — o papel \
                grosso resiste. Você segura até queimarem os seus dedos. Só \
                então deixa cair na lama.

                Alguma coisa dói. Mas você recusou uma promessa que não podia \
                ser verdade, e recusar promessas falsas te FORTALECE. Seu corpo \
                aguenta mais. Sua mãe verdadeira vai receber uma carta sua \
                daqui a três semanas, se você sobreviver.
                """
            ),
            EventChoice(
                id: "reply",
                label: "Responder como se fosse verdade",
                costHint: "+5 Moral · -3 Max Moral · +Sussurrar Verdade",
                effects: [
                    .gainMoral(5),
                    .gainMaxMoral(-3),
                    .addCard(templateID: "whisper_truth"),
                ],
                resultText: """
                Você pega papel. Escreve de volta.

                \u{201C}Mãe, a torta estava perfeita. Amanhã eu ajudo com o pão. \
                Estou dormindo mais que em anos. Obrigado por me esperar.\u{201D}

                Você endereça, sela, entrega ao correio da unidade. Sabe que a \
                carta nunca vai chegar — não à mãe verdadeira. Vai chegar em \
                outro lugar. Alguém, ou alguma coisa, vai ler o que você \
                escreveu, e vai aprender que você já sabe conversar do outro \
                lado. Isso é uma arma. Você agora tem essa arma.
                """
            ),
        ]
    )

    /// O Casaco do Henry — encontram um casaco pendurado no arame.
    static let henrysCoat = GameEvent(
        id: "henrys_coat",
        act: 3,
        title: "O Casaco no Arame",
        narrative: """
        No meio de um campo cortado por arame farpado, um casaco britânico \
        pendurado. Preso pelo ombro, como se alguém tivesse tirado com pressa. \
        Bom estado. Etiqueta interna com nome bordado:

        \u{201C}H. VALE\u{201D}

        Henry.

        Você comprou aquele casaco pra ele em 1913. Aquela etiqueta você \
        bordou, à mão, três noites acordado antes dele embarcar.
        """,
        choices: [
            EventChoice(
                id: "take",
                label: "Pegar o casaco e vestir por baixo",
                costHint: "-3 HP · +8 Max HP",
                effects: [.gainHP(-3), .gainMaxHP(8)],
                resultText: """
                Você retira o casaco do arame com cuidado. É pesado — mais do \
                que devia ser. Cheira a tabaco velho e a algo que você não \
                consegue nomear.

                Você tira o próprio capote, veste o de Henry por baixo do seu, \
                e recoloca o capote. Fica mais quente. Fica mais protegido. E \
                fica com uma sensação estranha de que alguém está te abraçando \
                por trás — o tempo todo, mesmo quando você está sozinho. Você \
                aprende a se acostumar. Isso te faz aguentar mais.
                """
            ),
            EventChoice(
                id: "cut_down",
                label: "Cortar e enterrar com respeito",
                costHint: "+8 Moral · -3 HP",
                effects: [.gainMoral(8), .gainHP(-3)],
                resultText: """
                Você corta o casaco do arame com a baioneta. Cava um buraco \
                raso num canto do campo, longe da estrada. Enterra o casaco \
                dobrado. Marca com duas pedras — uma pra cabeça, uma pra os pés.

                Não diz nenhuma prece. Não sabe rezar direito. Mas fica \
                agachado por um minuto inteiro com a mão sobre a terra fria. \
                Se levanta com o peito mais leve. Uma coisa que precisava \
                acontecer aconteceu.
                """
            ),
            EventChoice(
                id: "leave",
                label: "Deixar e continuar caminhando",
                costHint: "-8 Moral · +5 HP",
                effects: [.gainMoral(-8), .gainHP(5)],
                resultText: """
                Você olha por vinte segundos. Depois vira. Continua com a \
                unidade. Não fala nada. Petrov percebe, depois — pelo teu \
                silêncio nos próximos dois dias — que aconteceu alguma coisa, \
                mas ele não pergunta.

                Seu corpo se conserva. Sua mente também paga um preço que você \
                não sente ainda. Vai sentir. Ainda vai chegar.
                """
            ),
        ]
    )

    /// Oficial Sem Nome — um oficial britânico chega ao camp sem se identificar direito.
    static let officerWithoutName = GameEvent(
        id: "officer_without_name",
        act: 3,
        title: "Um Oficial que Não Se Apresenta",
        narrative: """
        Um homem em uniforme britânico de major chega ao acampamento à \
        cavalo. Insígnias corretas. Botas polidas. Cavalo saudável. Ele \
        pergunta pelo tenente responsável — por você.

        Quando você se apresenta, ele saúda como manual. Diz que traz ordens \
        de Whitehall. Passa um envelope selado.

        Você pergunta o nome dele. Ele sorri e não responde. Diz apenas: \
        \u{201C}Você não precisa do meu nome. Só precisa das minhas ordens.\u{201D}
        """,
        choices: [
            EventChoice(
                id: "open",
                label: "Abrir o envelope na frente dele",
                costHint: "-3 Moral · +5 Max Moral",
                effects: [.gainMoral(-3), .gainMaxMoral(5)],
                resultText: """
                Você quebra o selo. Tira a folha. Ela é branca. Completamente. \
                Sem uma linha, sem uma assinatura, sem cabeçalho.

                Você olha pro major. Ele mantém o sorriso. \u{201C}Excelente. \
                Você entendeu.\u{201D} Ele saúda de novo, monta, sai. Você fica \
                com a folha branca na mão.

                Aprende algo importante ali: às vezes a ordem é o gesto de \
                receber a ordem. Você fica com a mente mais forte por \
                reconhecer isso — mas também mais cansado.
                """
            ),
            EventChoice(
                id: "detain",
                label: "Deter o homem pra interrogar",
                costHint: "-8 HP · +8 Max HP",
                effects: [.gainHP(-8), .gainMaxHP(8)],
                resultText: """
                \u{201C}Petrov. Wardell. Prender esse homem até identificação \
                confirmada.\u{201D}

                Os dois avançam. O major não resiste — deixa cair as rédeas, \
                estende as mãos, ainda sorrindo. Vocês o levam pra tenda de \
                comando. Ashcroft manda telegrama pra Whitehall.

                Ao amanhecer, a tenda está vazia. As cordas cortadas por dentro. \
                O cavalo desaparecido. Nenhuma resposta do telegrama. Vocês \
                seguem em frente sabendo que fizeram a coisa certa — o esforço \
                fortalece o esquadrão de dentro pra fora. Custa fisicamente. \
                Vale.
                """
            ),
            EventChoice(
                id: "accept",
                label: "Aceitar sem questionar",
                costHint: "+5 HP · -5 Max Moral",
                effects: [.gainHP(5), .gainMaxMoral(-5)],
                resultText: """
                Você guarda o envelope no bolso interno do casaco. Saúda de \
                volta. O major monta e sai a cavalo pela estrada.

                Você dorme bem essa noite. Não abre o envelope. Vai carregar \
                ele pela guerra inteira sem quebrar o selo. Sua mente \
                encolhe um pouco por não querer saber — mas seu corpo \
                agradece a paz. É um trade-off que a guerra ensina.
                """
            ),
        ]
    )

    /// Ordens de Retaguarda — um mensageiro traz ordens contraditórias.
    static let rearGuardOrders = GameEvent(
        id: "rear_guard_orders",
        act: 3,
        title: "Ordens Contraditórias",
        narrative: """
        Dois mensageiros chegam no mesmo dia, com uma hora de diferença. Cada \
        um traz ordens seladas de Whitehall. Você abre as duas.

        A primeira ordem manda avançar imediatamente contra a posição alemã \
        de Bec-sur-Meuse.

        A segunda ordem manda recuar imediatamente pra Amiens e aguardar \
        instruções.

        Ambas são assinadas pelo mesmo general. Ambas têm o selo autêntico. \
        Ambas datadas hoje.
        """,
        choices: [
            EventChoice(
                id: "advance",
                label: "Obedecer a ordem de avançar",
                costHint: "-5 HP · +8 Moral",
                effects: [.gainHP(-5), .gainMoral(8)],
                resultText: """
                Você chama a unidade. Explica sucintamente. Marcha pra \
                Bec-sur-Meuse. A posição alemã está vazia quando vocês \
                chegam — não abandonada, VAZIA, como se nunca tivesse sido \
                ocupada. Vocês tomam a posição sem disparar um tiro.

                Semanas depois, o general envia uma condecoração. Você não \
                sabe qual das duas ordens era real. Não faz diferença agora. \
                Você agiu. Ação fortalece o moral da unidade — inclusive o \
                seu.
                """
            ),
            EventChoice(
                id: "retreat",
                label: "Obedecer a ordem de recuar",
                costHint: "+8 HP · -3 Moral",
                effects: [.gainHP(8), .gainMoral(-3)],
                resultText: """
                Você recua pra Amiens. Chegando lá, o quartel-general está \
                deserto. Nenhum superior. Nenhuma instrução seguinte. Vocês \
                acampam por três dias. No quarto dia, chega notícia: a \
                unidade que devia ter avançado pra Bec-sur-Meuse foi \
                aniquilada.

                Você não sabe se salvou seus homens ou se foi manipulado. \
                Seu corpo descansou — vocês estão em boa forma física. Sua \
                consciência não descansa. Mas você aceita o custo.
                """
            ),
            EventChoice(
                id: "burn_both",
                label: "Queimar as duas · seguir intuição",
                costHint: "-3 Moral · +10 Max HP · +Reserva Silenciosa",
                effects: [
                    .gainMoral(-3),
                    .gainMaxHP(10),
                    .addCard(templateID: "silent_reserve"),
                ],
                resultText: """
                Você queima os dois envelopes. Chama Petrov e Ashcroft. \
                Explica que nenhuma das ordens é confiável. Vocês três \
                decidem, em conjunto, marchar pra o vilarejo mais próximo, \
                estabelecer perímetro, aguardar informação real.

                O grupo passa uma semana lá. Ninguém morre. Ninguém dispara. \
                Você aprende a comandar SEM ordens vindas de cima — a \
                confiar na avaliação do próprio grupo. Isso te faz mais \
                forte de um jeito que a estrutura militar não teria ensinado.
                """
            ),
        ]
    )

    /// A Bandeira de Nove Pontas de Novo — reconhecimento crescente.
    static let ninePointedFlagAgain = GameEvent(
        id: "nine_pointed_flag_again",
        act: 3,
        title: "A Bandeira de Novo",
        narrative: """
        Você vê o símbolo pela terceira vez.

        Nove linhas partindo de um ponto central. Ouro fosco. Dessa vez pintado \
        na parede de uma capela abandonada no vilarejo de Meaulte. Está fresco. \
        A tinta ainda escorre um pouco na parte de baixo.

        Do lado de dentro da capela, alguém deixou uma mesa arrumada pra duas \
        pessoas. Vinho. Pão. Duas cadeiras. Uma delas está encostada. A outra \
        está afastada, como se esperando você sentar.
        """,
        choices: [
            EventChoice(
                id: "sit",
                label: "Sentar na cadeira",
                costHint: "-10 Moral · +Sussurrar Verdade",
                effects: [
                    .gainMoral(-10),
                    .addCard(templateID: "whisper_truth"),
                ],
                resultText: """
                Você senta. Ninguém aparece. Você espera dez minutos, uma \
                hora, duas horas. Ninguém aparece. Mas você começa a ouvir \
                — não com os ouvidos, com outra coisa — uma conversa em uma \
                língua que você não conhece mas ENTENDE.

                A conversa te ensina o nome verdadeiro daquela coisa. Você \
                não repete em voz alta. Você guarda. Sai da capela sabendo \
                falar a última palavra — a que ATINGE. E isso agora vive \
                dentro de você e não vai sair.
                """
            ),
            EventChoice(
                id: "destroy",
                label: "Apagar o símbolo com terra",
                costHint: "+8 Moral · -5 Max Moral",
                effects: [.gainMoral(8), .gainMaxMoral(-5)],
                resultText: """
                Você pega punhados de terra do chão de fora, esfrega contra o \
                símbolo, cobre linha por linha até que o ouro suma sob o \
                marrom. Leva vinte minutos. Suas mãos ficam em carne viva.

                Você sai da capela sem tocar na mesa. Dorme melhor essa noite \
                — mas alguma coisa da profundidade que ia se abrir NUNCA vai \
                se abrir. Você recusou. Vai carregar o peso silencioso de \
                não saber uma verdade que era sua pra saber.
                """
            ),
            EventChoice(
                id: "photograph",
                label: "Desenhar no diário e sair",
                costHint: "+3 Moral · -3 HP",
                effects: [.gainMoral(3), .gainHP(-3)],
                resultText: """
                Você tira o diário. Copia o símbolo com precisão máxima. \
                Anota data, local, condição da tinta, o arranjo da mesa. \
                Você é um oficial que documenta.

                Sai da capela sem tocar em nada. Ashcroft vai olhar pro \
                desenho depois. Vai reconhecer o símbolo. Vai fechar o \
                caderno em silêncio. Depois vai olhar pra você por um tempo \
                longo antes de dizer: \u{201C}Vale. Tem gente muito grande \
                interessada em você agora.\u{201D}
                """
            ),
        ]
    )
}
