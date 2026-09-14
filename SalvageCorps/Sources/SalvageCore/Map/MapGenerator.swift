import Foundation

/// Gerador de mapas por ato. Híbrido:
/// - Nós narrativos FIXOS em posições pré-definidas (garantem arco de história)
/// - Nós PROCEDURAIS preenchem o resto (garantem rejogabilidade)
///
/// Uso:
/// ```
/// var rng = SeededRandom(seed: 12345)
/// let map = MapGenerator.generate(act: 1, rng: &rng)
/// ```
public enum MapGenerator {

    // ========================================================================
    // MARK: - Blueprint por ato (fixed nodes)
    // ========================================================================

    /// Blueprint narrativo do Ato 1.
    ///
    /// A ordem/posição dos nós narrativos aqui determina o ritmo do ato.
    /// Colunas 0-8, com boss em 8. Camp obrigatório em 6 (pré-boss).
    /// Evento "Petrov's Warning" em 2 estabelece Petrov como personagem.
    /// Elite em 4 aumenta a tensão no meio.
    private static let act1Blueprint: [ActBlueprintEntry] = [
        // Início: eventos suaves pra introduzir mecânicas
        .init(column: 0, row: 1, kind: .combat, narrativeID: "opening_patrol"),

        // Coluna 2: evento narrativo obrigatório com Petrov
        .init(column: 2, row: 1, kind: .event, narrativeID: "petrov_warning"),

        // Elite no meio pra pico de dificuldade
        .init(column: 4, row: 1, kind: .elite, narrativeID: "trench_47_incident"),

        // Camp pré-boss obrigatório (última chance de preparar)
        .init(column: 6, row: 1, kind: .camp, narrativeID: "final_camp"),

        // Boss final do ato
        .init(column: 8, row: 1, kind: .boss, narrativeID: "hauptmann_kruger"),
    ]

    /// Blueprint do Ato 2 (será expandido na Fase 2).
    private static let act2Blueprint: [ActBlueprintEntry] = [
        .init(column: 0, row: 1, kind: .combat, narrativeID: "descent_begin"),
        .init(column: 3, row: 1, kind: .event, narrativeID: "ashcroft_revelation"),
        .init(column: 5, row: 1, kind: .elite, narrativeID: "gas_wraith_ambush"),
        .init(column: 7, row: 1, kind: .camp, narrativeID: "underground_camp"),
        .init(column: 9, row: 1, kind: .boss, narrativeID: "barbed_apostle"),
    ]

    /// Blueprint do Ato 3 (será expandido na Fase 3).
    private static let act3Blueprint: [ActBlueprintEntry] = [
        .init(column: 0, row: 1, kind: .combat, narrativeID: "return_home"),
        .init(column: 3, row: 1, kind: .event, narrativeID: "henry_appears"),
        .init(column: 5, row: 1, kind: .event, narrativeID: "mirror_test"),
        .init(column: 7, row: 1, kind: .camp, narrativeID: "final_reckoning"),
        .init(column: 9, row: 1, kind: .boss, narrativeID: "generals_ghost"),
    ]

    // ========================================================================
    // MARK: - Configuração de geração procedural
    // ========================================================================

    /// Configuração de quantos nós por coluna procedural.
    private struct ProceduralConfig {
        let rowsPerColumn: ClosedRange<Int>  // ex: 2...4 nós por coluna
        let combatWeight: Int
        let eventWeight: Int
        let eliteWeight: Int
        let campWeight: Int

        static let act1 = ProceduralConfig(
            rowsPerColumn: 2...3,
            combatWeight: 60,   // 60% combate normal
            eventWeight: 20,    // 20% evento
            eliteWeight: 15,    // 15% elite
            campWeight: 5       // 5% camp extra (raro)
        )

        static let act2 = ProceduralConfig(
            rowsPerColumn: 3...4,
            combatWeight: 55,
            eventWeight: 20,
            eliteWeight: 20,
            campWeight: 5
        )

        static let act3 = ProceduralConfig(
            rowsPerColumn: 3...4,
            combatWeight: 50,
            eventWeight: 25,
            eliteWeight: 20,
            campWeight: 5
        )
    }

    // ========================================================================
    // MARK: - Public API
    // ========================================================================

    /// Gera um mapa completo pro ato dado.
    public static func generate(act: Int, rng: inout SeededRandom) -> GameMap {
        let blueprint: [ActBlueprintEntry]
        let config: ProceduralConfig

        switch act {
        case 1:
            blueprint = act1Blueprint
            config = .act1
        case 2:
            blueprint = act2Blueprint
            config = .act2
        case 3:
            blueprint = act3Blueprint
            config = .act3
        default:
            blueprint = act1Blueprint
            config = .act1
        }

        let bossColumn = blueprint.first { $0.kind == .boss }?.column ?? 8

        // 1) Cria todos os nós — fixos + procedurais
        var allNodes: [MapNode] = []
        var occupiedPositions: Set<MapPosition> = []

        // Fixed nodes primeiro
        for entry in blueprint {
            let position = MapPosition(column: entry.column, row: entry.row)
            let node = MapNode(
                position: position,
                kind: entry.kind,
                isFixed: true,
                narrativeID: entry.narrativeID
            )
            allNodes.append(node)
            occupiedPositions.insert(position)
        }

        // Preenche colunas com nós procedurais
        for column in 0...bossColumn {
            let fixedInColumn = allNodes.filter { $0.position.column == column }
            let rowsToAdd = rng.int(in: config.rowsPerColumn) - fixedInColumn.count

            if rowsToAdd <= 0 { continue }

            // Determina posições disponíveis (rows 0, 1, 2, 3)
            let usedRows = Set(fixedInColumn.map { $0.position.row })
            let availableRows = (0..<4).filter { !usedRows.contains($0) }.shuffled(using: &rng)

            // Nunca gera nós procedurais na coluna do boss
            let allowedKinds = (column == bossColumn)
                ? []
                : proceduralKinds(config: config)

            for i in 0..<min(rowsToAdd, availableRows.count) {
                guard !allowedKinds.isEmpty else { continue }
                let kind = weightedPick(allowedKinds, rng: &rng)
                let node = MapNode(
                    position: MapPosition(column: column, row: availableRows[i]),
                    kind: kind,
                    isFixed: false
                )
                allNodes.append(node)
            }
        }

        // 2) Cria edges entre colunas adjacentes
        let edges = generateEdges(nodes: allNodes, bossColumn: bossColumn, rng: &rng)

        // 3) Identifica start + boss
        let startNodeIDs = allNodes.filter { $0.position.column == 0 }.map { $0.id }
        let bossNodeID = allNodes.first { $0.kind == .boss }?.id ?? allNodes.last!.id

        return GameMap(
            act: act,
            nodes: allNodes,
            edges: edges,
            startNodeIDs: startNodeIDs,
            bossNodeID: bossNodeID
        )
    }

    // ========================================================================
    // MARK: - Edge generation
    // ========================================================================

    /// Gera edges garantindo que:
    /// - Todo nó (exceto boss) tem pelo menos 1 edge saindo pra próxima coluna
    /// - Todo nó (exceto start) tem pelo menos 1 edge chegando
    /// - Boss é acessível a partir do camp pré-boss (fixed edge)
    /// - Sem cross-crossing radical (evita spaghetti visual)
    private static func generateEdges(
        nodes: [MapNode],
        bossColumn: Int,
        rng: inout SeededRandom
    ) -> [MapEdge] {
        var edges: [MapEdge] = []

        for column in 0..<bossColumn {
            let current = nodes.filter { $0.position.column == column }
                .sorted { $0.position.row < $1.position.row }
            let next = nodes.filter { $0.position.column == column + 1 }
                .sorted { $0.position.row < $1.position.row }

            guard !next.isEmpty else { continue }

            // Para cada nó da coluna atual, conecta a 1-2 nós da próxima
            for node in current {
                // Nós vizinhos verticalmente (row +/-1) são candidatos preferidos
                let candidates = next.filter { abs($0.position.row - node.position.row) <= 1 }
                let pool = candidates.isEmpty ? next : candidates

                // Sempre 1 edge, chance de 2ª
                let count = rng.int(in: 1...2)
                let picks = Array(pool.shuffled(using: &rng).prefix(min(count, pool.count)))

                for target in picks {
                    let edge = MapEdge(from: node.id, to: target.id)
                    if !edges.contains(edge) {
                        edges.append(edge)
                    }
                }
            }

            // Garante que todo nó da PRÓXIMA coluna tem pelo menos 1 entrada
            for target in next {
                let hasIncoming = edges.contains { $0.to == target.id }
                if !hasIncoming {
                    // Pega o nó mais próximo verticalmente da coluna anterior
                    let closest = current.min { a, b in
                        abs(a.position.row - target.position.row) < abs(b.position.row - target.position.row)
                    }
                    if let closest {
                        edges.append(MapEdge(from: closest.id, to: target.id))
                    }
                }
            }
        }

        return edges
    }

    // ========================================================================
    // MARK: - Helpers
    // ========================================================================

    private static func proceduralKinds(config: ProceduralConfig) -> [(NodeKind, Int)] {
        [
            (.combat, config.combatWeight),
            (.event, config.eventWeight),
            (.elite, config.eliteWeight),
            (.camp, config.campWeight),
        ]
    }

    private static func weightedPick(
        _ choices: [(NodeKind, Int)],
        rng: inout SeededRandom
    ) -> NodeKind {
        let total = choices.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return choices[0].0 }
        var pick = rng.int(in: 0...(total - 1))
        for (kind, weight) in choices {
            if pick < weight { return kind }
            pick -= weight
        }
        return choices[0].0
    }
}

// ============================================================================
// MARK: - Support
// ============================================================================

private struct ActBlueprintEntry {
    let column: Int
    let row: Int
    let kind: NodeKind
    let narrativeID: String

    init(column: Int, row: Int, kind: NodeKind, narrativeID: String) {
        self.column = column
        self.row = row
        self.kind = kind
        self.narrativeID = narrativeID
    }
}
