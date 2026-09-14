//
//  MatchHistoryStore.swift
//  Salvage Corps
//
//  Fase 10: histórico persistido dos últimos matches ranked. Cada entrada
//  guarda info mínima pra render uma linha "vitória/derrota vs X, +24".
//  Alimentado por DuelMatchStore.applyRatingIfDuelEnded.
//

import Foundation
import Observation
import SalvageCore

// MARK: - Entry

struct MatchHistoryEntry: Codable, Equatable, Identifiable {

    /// UUID do registro (não é o matchID do Game Center — isso vai em `matchID`).
    /// Serve pra usar como `id` em `ForEach`.
    var id: UUID

    /// `GKTurnBasedMatch.matchID` — usado pra deduplicação (nunca registrar 2x).
    let matchID: String

    /// Nome do adversário no momento do fim do match. Pode ficar defasado se
    /// o Apple ID do adversário mudou de displayName depois — improvável.
    let opponentName: String

    /// Rating congelado do adversário no início. Serve pra mostrar tier deles
    /// na linha do histórico.
    let opponentRatingAtStart: Int

    /// True se eu ganhei.
    let iWon: Bool

    /// Delta ELO aplicado (positivo se ganhei, negativo se perdi).
    let delta: Int

    /// Meu rating DEPOIS de aplicar o delta.
    let myRatingAfter: Int

    /// Momento em que o registro foi gravado. Usado pra ordenar e mostrar
    /// "há 3 dias".
    let timestamp: Date

    init(
        matchID: String,
        opponentName: String,
        opponentRatingAtStart: Int,
        iWon: Bool,
        delta: Int,
        myRatingAfter: Int,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.matchID = matchID
        self.opponentName = opponentName
        self.opponentRatingAtStart = opponentRatingAtStart
        self.iWon = iWon
        self.delta = delta
        self.myRatingAfter = myRatingAfter
        self.timestamp = timestamp
    }
}

// MARK: - Store

@Observable
@MainActor
final class MatchHistoryStore {

    static let shared = MatchHistoryStore()

    /// Máximo de entradas guardadas — mantém as N mais recentes.
    /// Roll-over silencioso quando estoura.
    static let maxEntries: Int = 100

    /// Histórico ordenado do mais recente pro mais antigo.
    private(set) var entries: [MatchHistoryEntry]

    private static let key = "sc.duel.matchHistory.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let loaded = try? JSONDecoder().decode([MatchHistoryEntry].self, from: data) {
            self.entries = loaded
        } else {
            self.entries = []
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else {
            print("[MatchHistory] Falha ao serializar histórico")
            return
        }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    // MARK: Record

    /// Grava nova entrada. Idempotente por `matchID` — se já existe entrada com
    /// mesmo matchID, retorna false e não grava. Insere no início (mais recente
    /// primeiro) e trunca se exceder `maxEntries`.
    @discardableResult
    func record(_ entry: MatchHistoryEntry) -> Bool {
        if entries.contains(where: { $0.matchID == entry.matchID }) {
            print("[MatchHistory] Match \(entry.matchID) já registrado — pulando")
            return false
        }
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        persist()
        return true
    }

    /// Limpa todo o histórico. Só chame em dev.
    func devClear() {
        entries = []
        persist()
        print("[MatchHistory] DEV CLEAR aplicado")
    }
}
