import Foundation

// ============================================================================
// MARK: - Node Kinds
// ============================================================================

/// Tipo de nó no mapa do ato.
///
/// Fixado por design: cada tipo tem propósito claro no pacing.
/// - `combat`: pilar do jogo. Combate normal, recompensa em cicatriz.
/// - `elite`: mais difícil, recompensa melhor (upgrade + cura?).
/// - `boss`: fim do ato. Único por mapa. Multi-phase.
/// - `camp`: descanso. Cura + upgrade + diálogo NPC.
/// - `event`: escolha narrativa, sem combate. Afeta stats/deck/ending.
/// - `merchant`: [futuro] compra cartas/relíquias.
public enum NodeKind: String, Codable, Sendable, CaseIterable {
    case combat
    case elite
    case boss
    case camp
    case event
    case merchant
}

// ============================================================================
// MARK: - Position
// ============================================================================

/// Posição do nó na grade do mapa.
///
/// `column` = profundidade no ato (0 = início, N = boss).
/// `row` = posição vertical na coluna (0 = topo).
///
/// Design de mapa Slay-the-Spire style: player avança coluna por coluna,
/// escolhendo entre nós paralelos da próxima coluna.
public struct MapPosition: Hashable, Codable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

// ============================================================================
// MARK: - Node
// ============================================================================

public struct MapNode: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let position: MapPosition
    public let kind: NodeKind

    /// Se true, este nó foi definido pela estrutura narrativa (fixed).
    /// Se false, foi gerado proceduralmente (filler).
    public let isFixed: Bool

    /// Identificador narrativo opcional (apenas nodes fixed).
    /// Ex: "petrov_warning", "trench_47_incident".
    /// Usado pra carregar conteúdo específico (evento, diálogo, encounter).
    public let narrativeID: String?

    public init(
        id: UUID = UUID(),
        position: MapPosition,
        kind: NodeKind,
        isFixed: Bool = false,
        narrativeID: String? = nil
    ) {
        self.id = id
        self.position = position
        self.kind = kind
        self.isFixed = isFixed
        self.narrativeID = narrativeID
    }
}

// ============================================================================
// MARK: - Edge
// ============================================================================

/// Aresta direcional entre 2 nós. Player só pode navegar seguindo edges.
///
/// Regra de geração: edges só conectam colunas ADJACENTES (from.column + 1 = to.column).
/// Não pode pular colunas. Não pode voltar.
public struct MapEdge: Codable, Equatable, Hashable, Sendable {
    public let from: UUID
    public let to: UUID

    public init(from: UUID, to: UUID) {
        self.from = from
        self.to = to
    }
}

// ============================================================================
// MARK: - Map
// ============================================================================

/// Mapa completo de um ato.
///
/// Value type. Codable pra persistência. Gerado uma vez por run
/// via `MapGenerator`, imutável durante a run.
public struct GameMap: Codable, Equatable, Sendable {
    public let act: Int
    public let nodes: [MapNode]
    public let edges: [MapEdge]

    /// Nós iniciais (coluna 0). Player escolhe qual seguir.
    public let startNodeIDs: [UUID]

    /// Boss node (última coluna, único).
    public let bossNodeID: UUID

    public init(
        act: Int,
        nodes: [MapNode],
        edges: [MapEdge],
        startNodeIDs: [UUID],
        bossNodeID: UUID
    ) {
        self.act = act
        self.nodes = nodes
        self.edges = edges
        self.startNodeIDs = startNodeIDs
        self.bossNodeID = bossNodeID
    }

    // MARK: - Queries

    public func node(id: UUID) -> MapNode? {
        nodes.first { $0.id == id }
    }

    public func nodes(inColumn column: Int) -> [MapNode] {
        nodes.filter { $0.position.column == column }.sorted { $0.position.row < $1.position.row }
    }

    public var columnCount: Int {
        (nodes.map { $0.position.column }.max() ?? 0) + 1
    }

    /// Retorna os IDs dos próximos nós acessíveis a partir de `nodeID`.
    public func nextNodes(from nodeID: UUID) -> [UUID] {
        edges.filter { $0.from == nodeID }.map { $0.to }
    }

    /// Retorna os nós anteriores que apontam pra `nodeID` (útil pra debug/visualização).
    public func previousNodes(to nodeID: UUID) -> [UUID] {
        edges.filter { $0.to == nodeID }.map { $0.from }
    }
}
