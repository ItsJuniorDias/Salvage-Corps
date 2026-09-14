import Foundation

/// Estado imutável da progressão do jogador entre operações.
///
/// Puro value type. Codable pra persistência trivial via UserDefaults.
/// A ordem das operações vem de `Operation.allCases`.
public struct PlayerProgress: Codable, Equatable, Sendable {

    public private(set) var completedOperations: Set<Operation>
    public private(set) var lastCompletedAt: [Operation: Date]

    public init() {
        self.completedOperations = []
        self.lastCompletedAt = [:]
    }

    // MARK: - Mutations

    public mutating func markCompleted(_ operation: Operation, at date: Date = Date()) {
        completedOperations.insert(operation)
        lastCompletedAt[operation] = date
    }

    public mutating func reset() {
        completedOperations.removeAll()
        lastCompletedAt.removeAll()
    }

    // MARK: - Queries

    public func isCompleted(_ operation: Operation) -> Bool {
        completedOperations.contains(operation)
    }

    /// Uma operação está desbloqueada se é a primeira OU a anterior já foi completada.
    public func isUnlocked(_ operation: Operation) -> Bool {
        let all = Operation.allCases
        guard let idx = all.firstIndex(of: operation) else { return false }
        if idx == 0 { return true }
        return isCompleted(all[idx - 1])
    }

    public func status(_ operation: Operation) -> OperationStatus {
        if isCompleted(operation) { return .completed }
        if isUnlocked(operation) { return .available }
        return .locked
    }

    /// A próxima operação disponível ainda não completada.
    /// Retorna nil se tudo foi completado (fim do Ato 1).
    public var nextAvailable: Operation? {
        Operation.allCases.first { isUnlocked($0) && !isCompleted($0) }
    }

    public var allCompleted: Bool {
        Operation.allCases.allSatisfy { isCompleted($0) }
    }

    /// Quantidade de operações completadas (útil pra progress bar).
    public var completedCount: Int {
        completedOperations.count
    }

    public var totalCount: Int {
        Operation.allCases.count
    }
}

/// Estado de uma operação pra fins de UI.
public enum OperationStatus: String, Codable, Sendable {
    case locked
    case available
    case completed
}
