import XCTest
@testable import SalvageCore

final class MapGeneratorTests: XCTestCase {

    // MARK: - Determinismo

    func test_generate_sameSeed_producesSameMap() {
        var rng1 = SeededRandom(seed: 12345)
        var rng2 = SeededRandom(seed: 12345)
        let map1 = MapGenerator.generate(act: 1, rng: &rng1)
        let map2 = MapGenerator.generate(act: 1, rng: &rng2)

        XCTAssertEqual(map1.nodes.count, map2.nodes.count)
        XCTAssertEqual(map1.edges.count, map2.edges.count)
        // Nós na mesma posição devem ter o mesmo kind
        for n1 in map1.nodes {
            let n2 = map2.nodes.first { $0.position == n1.position }
            XCTAssertNotNil(n2)
            XCTAssertEqual(n1.kind, n2?.kind)
        }
    }

    func test_generate_differentSeeds_produceDifferentMaps() {
        var rng1 = SeededRandom(seed: 111)
        var rng2 = SeededRandom(seed: 222)
        let map1 = MapGenerator.generate(act: 1, rng: &rng1)
        let map2 = MapGenerator.generate(act: 1, rng: &rng2)
        // Pelo menos algum nó procedural deve diferir
        let kinds1 = map1.nodes.filter { !$0.isFixed }.map { $0.kind }
        let kinds2 = map2.nodes.filter { !$0.isFixed }.map { $0.kind }
        XCTAssertNotEqual(kinds1, kinds2)
    }

    // MARK: - Estrutura narrativa (fixed nodes)

    func test_act1_hasRequiredNarrativeNodes() {
        var rng = SeededRandom(seed: 42)
        let map = MapGenerator.generate(act: 1, rng: &rng)

        let narrativeIDs = map.nodes.compactMap { $0.narrativeID }
        XCTAssertTrue(narrativeIDs.contains("opening_patrol"))
        XCTAssertTrue(narrativeIDs.contains("petrov_warning"))
        XCTAssertTrue(narrativeIDs.contains("trench_47_incident"))
        XCTAssertTrue(narrativeIDs.contains("final_camp"))
        XCTAssertTrue(narrativeIDs.contains("hauptmann_kruger"))
    }

    func test_act1_hasExactlyOneBoss() {
        var rng = SeededRandom(seed: 42)
        let map = MapGenerator.generate(act: 1, rng: &rng)

        let bosses = map.nodes.filter { $0.kind == .boss }
        XCTAssertEqual(bosses.count, 1)
        XCTAssertEqual(bosses.first?.id, map.bossNodeID)
    }

    func test_act1_bossIsInLastColumn() {
        var rng = SeededRandom(seed: 42)
        let map = MapGenerator.generate(act: 1, rng: &rng)

        let boss = map.node(id: map.bossNodeID)!
        let maxColumn = map.nodes.map { $0.position.column }.max()!
        XCTAssertEqual(boss.position.column, maxColumn)
    }

    // MARK: - Conectividade do grafo

    func test_everyNonBossNode_hasOutgoingEdge() {
        var rng = SeededRandom(seed: 42)
        let map = MapGenerator.generate(act: 1, rng: &rng)

        for node in map.nodes where node.id != map.bossNodeID {
            let outgoing = map.nextNodes(from: node.id)
            XCTAssertFalse(outgoing.isEmpty, "Nó \(node.position) (\(node.kind)) sem saída")
        }
    }

    func test_everyNonStartNode_hasIncomingEdge() {
        var rng = SeededRandom(seed: 42)
        let map = MapGenerator.generate(act: 1, rng: &rng)

        let startIDs = Set(map.startNodeIDs)
        for node in map.nodes where !startIDs.contains(node.id) {
            let incoming = map.previousNodes(to: node.id)
            XCTAssertFalse(incoming.isEmpty, "Nó \(node.position) (\(node.kind)) inacessível")
        }
    }

    func test_edges_onlyConnectAdjacentColumns() {
        var rng = SeededRandom(seed: 42)
        let map = MapGenerator.generate(act: 1, rng: &rng)

        for edge in map.edges {
            let from = map.node(id: edge.from)!
            let to = map.node(id: edge.to)!
            XCTAssertEqual(
                to.position.column - from.position.column, 1,
                "Edge de \(from.position) pra \(to.position) pula colunas"
            )
        }
    }

    // MARK: - Balanço procedural

    func test_act1_hasCombatMajority() {
        // Rodar múltiplas seeds e verificar que combate é a maioria dos nós procedurais
        var totalProcedural = 0
        var totalCombat = 0

        for seed in 1...20 {
            var rng = SeededRandom(seed: UInt64(seed))
            let map = MapGenerator.generate(act: 1, rng: &rng)
            let procedural = map.nodes.filter { !$0.isFixed }
            totalProcedural += procedural.count
            totalCombat += procedural.filter { $0.kind == .combat }.count
        }

        let combatRatio = Double(totalCombat) / Double(totalProcedural)
        XCTAssertGreaterThan(combatRatio, 0.4, "Combate deveria ser >40% dos nós procedurais")
    }

    // MARK: - Alcançabilidade do boss

    func test_bossIsReachableFromAnyStart() {
        var rng = SeededRandom(seed: 42)
        let map = MapGenerator.generate(act: 1, rng: &rng)

        for startID in map.startNodeIDs {
            XCTAssertTrue(
                pathExists(from: startID, to: map.bossNodeID, in: map),
                "Boss inacessível do start \(startID)"
            )
        }
    }

    /// BFS pra confirmar que existe path.
    private func pathExists(from start: UUID, to target: UUID, in map: GameMap) -> Bool {
        var visited: Set<UUID> = [start]
        var queue: [UUID] = [start]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == target { return true }
            for next in map.nextNodes(from: current) where !visited.contains(next) {
                visited.insert(next)
                queue.append(next)
            }
        }
        return false
    }
}
