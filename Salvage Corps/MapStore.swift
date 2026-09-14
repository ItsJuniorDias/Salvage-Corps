//
//  MapStore.swift
//  Salvage Corps
//
//  Estado da run atual: mapa gerado, nó atual, nós resolvidos,
//  HP/Moral acumulados do player, e ações de camp já consumidas.
//
//  Semântica:
//  - `resolvedNodeIDs`: nós completados com SUCESSO (venceu, resolveu).
//    Só resolvidos desbloqueiam próximos.
//  - `runPlayerState`: HP/Moral persistem entre combates.
//    Combate lê no início, escreve no fim.
//  - `usedCampActions`: quais ações do camp já foram usadas neste run.
//    Chave: "nodeUUID:actionType" ex: "abc-123:rest", "abc-123:dialogue:petrov".
//

import Foundation
import Observation
import SalvageCore

@Observable
final class MapStore {

    private static let filename = "current_run.json"
    private static let legacyStorageKey = "salvage.currentRun.v2"

    // MARK: - State

    private(set) var currentMap: GameMap?
    private(set) var currentNodeID: UUID?
    private(set) var resolvedNodeIDs: Set<UUID>
    private(set) var runPlayerState: RunPlayerState
    private(set) var usedCampActions: Set<String>
    private(set) var playerDeck: PlayerDeck

    var currentAct: Int { currentMap?.act ?? 1 }
    var hasActiveRun: Bool { currentMap != nil }

    init() {
        self.currentMap = nil
        self.currentNodeID = nil
        self.resolvedNodeIDs = []
        self.runPlayerState = RunPlayerState()
        self.usedCampActions = []
        self.playerDeck = PlayerDeck()
        loadFromStorage()
    }

    // MARK: - Run lifecycle

    func startNewRun(act: Int, seed: UInt64? = nil) {
        var rng = SeededRandom(seed: seed ?? UInt64.random(in: 1...UInt64.max))
        let map = MapGenerator.generate(act: act, rng: &rng)

        self.currentMap = map
        self.currentNodeID = nil
        self.resolvedNodeIDs = []
        self.runPlayerState = RunPlayerState()  // reseta HP/Moral pra full
        self.usedCampActions = []
        self.playerDeck = PlayerDeck()  // reseta cicatrizes

        persist()
    }

    func abandonRun() {
        self.currentMap = nil
        self.currentNodeID = nil
        self.resolvedNodeIDs = []
        self.runPlayerState = RunPlayerState()
        self.usedCampActions = []
        self.playerDeck = PlayerDeck()
        persist()
    }

    /// Aplica um upgrade a uma carta. Retorna true se aplicou (novo template).
    /// Se o template já tem upgrade, sobrescreve.
    @discardableResult
    func applyCardUpgrade(templateID: String, upgradeID: String) -> Bool {
        playerDeck.applyUpgrade(templateID: templateID, upgradeID: upgradeID)
        persist()
        return true
    }

    // MARK: - Event effects

    /// Aplica uma lista de effects vindos de escolha de EventChoice.
    /// Mutations agrupadas + persist único no final.
    func applyEventEffects(_ effects: [EventEffect]) {
        for effect in effects {
            switch effect {
            case .gainHP(let n):
                runPlayerState.changeHP(by: n)
            case .gainMoral(let n):
                runPlayerState.changeMoral(by: n)
            case .gainMaxHP(let n):
                runPlayerState.changeMaxHP(by: n)
            case .gainMaxMoral(let n):
                runPlayerState.changeMaxMoral(by: n)
            case .applyScar(let templateID, let upgradeID):
                playerDeck.applyUpgrade(templateID: templateID, upgradeID: upgradeID)
            case .addCard(let templateID):
                playerDeck.addExtraCard(templateID: templateID)
            }
        }
        persist()
    }

    // MARK: - Navigation

    var availableNextNodes: [MapNode] {
        guard let map = currentMap else { return [] }

        guard let currentID = currentNodeID else {
            return map.startNodeIDs.compactMap { map.node(id: $0) }
        }

        if resolvedNodeIDs.contains(currentID) {
            return map.nextNodes(from: currentID).compactMap { map.node(id: $0) }
        } else {
            return map.node(id: currentID).map { [$0] } ?? []
        }
    }

    @discardableResult
    func moveToNode(_ nodeID: UUID) -> Bool {
        guard let map = currentMap else { return false }
        let available = availableNextNodes.map { $0.id }
        guard available.contains(nodeID) else {
            print("MapStore: navegação inválida pra \(nodeID)")
            return false
        }

        currentNodeID = nodeID
        persist()
        return true
    }

    func markCurrentNodeResolved() {
        guard let currentNodeID else { return }
        resolvedNodeIDs.insert(currentNodeID)
        maybeInjectGhostCard()
        persist()
    }

    // MARK: - Meta layer Ato 3 (ghost cards H.)

    /// Injeta ghost card H. no deck se estivermos no Ato 3 E em trigger específico.
    ///
    /// Triggers:
    /// - `ghost_h_1` (Silêncio): após 1º combat/elite completado do Ato 3
    /// - `ghost_h_2` (Presença): após 1º camp visitado do Ato 3
    /// - `ghost_h_3` (Consciência): quando entrou no penúltimo passo (elite ou último combate)
    ///
    /// Idempotente — nunca duplica (checa se já tem no extraCards).
    private func maybeInjectGhostCard() {
        guard currentAct == 3,
              let map = currentMap,
              let currentID = currentNodeID,
              let currentNode = map.node(id: currentID) else { return }

        let alreadyHas: (String) -> Bool = { [self] tid in
            playerDeck.extraCards.contains(tid)
        }

        // Trigger 1: primeiro combate completado
        if currentNode.kind == .combat || currentNode.kind == .elite {
            let combatsResolved = resolvedNodeIDs.compactMap { id -> NodeKind? in
                map.node(id: id)?.kind
            }.filter { $0 == .combat || $0 == .elite }.count

            if combatsResolved >= 1 && !alreadyHas("ghost_h_1") {
                playerDeck.addExtraCard(templateID: "ghost_h_1")
                print("META: ghost_h_1 injetada (após \(combatsResolved) combates)")
            }
        }

        // Trigger 2: primeiro camp visitado
        if currentNode.kind == .camp && !alreadyHas("ghost_h_2") {
            playerDeck.addExtraCard(templateID: "ghost_h_2")
            print("META: ghost_h_2 injetada (primeiro camp)")
        }

        // Trigger 3: antes do boss — quando resolveu o elite (último combate pre-boss)
        if currentNode.kind == .elite && !alreadyHas("ghost_h_3") {
            playerDeck.addExtraCard(templateID: "ghost_h_3")
            print("META: ghost_h_3 injetada (após elite, antes do boss)")
        }
    }

    /// Quantas ghost cards H. foram injetadas nesta run. Usado por
    /// EndingCalculator pra condições do Espelho.
    var ghostCardsInDeck: Int {
        playerDeck.extraCards.filter { $0.hasPrefix("ghost_h_") }.count
    }

    // MARK: - Player state (HP/Moral entre combates)

    /// Atualiza HP/Moral após combate.
    func updateRunPlayerStateAfterCombat(hp: Int, moral: Int) {
        runPlayerState.updateFromCombat(hp: hp, moral: moral)
        persist()
    }

    /// Aplica repouso no camp atual. Retorna true se foi aplicado.
    /// Já respeita "1x por camp" (verifica usedCampActions).
    @discardableResult
    func restAtCurrentCamp() -> Bool {
        guard let nodeID = currentNodeID else { return false }
        let key = campActionKey(nodeID: nodeID, action: "rest")
        guard !usedCampActions.contains(key) else { return false }

        runPlayerState.rest()
        usedCampActions.insert(key)
        persist()
        return true
    }

    /// Marca um diálogo com NPC como já consumido neste camp.
    func markDialogueUsed(nodeID: UUID, npc: NPC) {
        let key = campActionKey(nodeID: nodeID, action: "dialogue:\(npc.rawValue)")
        usedCampActions.insert(key)
        persist()
    }

    /// Marca a ação Refletir como usada neste camp (1x por camp).
    @discardableResult
    func markReflectUsed(nodeID: UUID) -> Bool {
        let key = campActionKey(nodeID: nodeID, action: "reflect")
        guard !usedCampActions.contains(key) else { return false }
        usedCampActions.insert(key)
        persist()
        return true
    }

    // MARK: - Queries de camp

    func isRestAvailable(atNodeID nodeID: UUID) -> Bool {
        !usedCampActions.contains(campActionKey(nodeID: nodeID, action: "rest"))
    }

    func isDialogueAvailable(atNodeID nodeID: UUID, npc: NPC) -> Bool {
        !usedCampActions.contains(campActionKey(nodeID: nodeID, action: "dialogue:\(npc.rawValue)"))
    }

    // MARK: - Queries gerais

    func isResolved(_ nodeID: UUID) -> Bool { resolvedNodeIDs.contains(nodeID) }
    func isVisited(_ nodeID: UUID) -> Bool { isResolved(nodeID) }
    func isCurrent(_ nodeID: UUID) -> Bool { currentNodeID == nodeID }
    func isAvailable(_ nodeID: UUID) -> Bool {
        availableNextNodes.contains { $0.id == nodeID }
    }

    var currentNode: MapNode? {
        guard let currentNodeID, let map = currentMap else { return nil }
        return map.node(id: currentNodeID)
    }

    // MARK: - Helpers

    private func campActionKey(nodeID: UUID, action: String) -> String {
        "\(nodeID.uuidString):\(action)"
    }

    // MARK: - Persistence

    private struct SavePayload: Codable {
        let map: GameMap
        let currentNodeID: UUID?
        let resolvedNodeIDs: [UUID]
        let runPlayerState: RunPlayerState
        let usedCampActions: [String]
        let playerDeck: PlayerDeck?  // opcional pra compat com saves antigos
    }

    private func persist() {
        guard let map = currentMap else {
            // Run terminou — deleta save
            try? FileStorage.delete(Self.filename)
            UserDefaults.standard.removeObject(forKey: Self.legacyStorageKey)
            return
        }
        let payload = SavePayload(
            map: map,
            currentNodeID: currentNodeID,
            resolvedNodeIDs: Array(resolvedNodeIDs),
            runPlayerState: runPlayerState,
            usedCampActions: Array(usedCampActions),
            playerDeck: playerDeck
        )
        do {
            try FileStorage.save(payload, to: Self.filename)
        } catch {
            print("MapStore: erro persistindo — \(error)")
        }
    }

    private func loadFromStorage() {
        // 1. Tenta carregar do FileStorage (Documents/)
        if let payload = FileStorage.load(SavePayload.self, from: Self.filename) {
            applyPayload(payload)
            print("MapStore: run carregada do file — ato \(payload.map.act), HP \(payload.runPlayerState.hp)/\(payload.runPlayerState.maxHP), \(playerDeck.upgradeCount) cicatrizes")
            return
        }

        // 2. Migração one-time: UserDefaults → File
        if let migrated = FileStorage.migrateFromUserDefaults(
            SavePayload.self,
            userDefaultsKey: Self.legacyStorageKey,
            toFilename: Self.filename
        ) {
            applyPayload(migrated)
            print("MapStore: migrado de UserDefaults — ato \(migrated.map.act)")
        }
    }

    private func applyPayload(_ payload: SavePayload) {
        self.currentMap = payload.map
        self.currentNodeID = payload.currentNodeID
        self.resolvedNodeIDs = Set(payload.resolvedNodeIDs)
        self.runPlayerState = payload.runPlayerState
        self.usedCampActions = Set(payload.usedCampActions)
        self.playerDeck = payload.playerDeck ?? PlayerDeck()
    }
}
