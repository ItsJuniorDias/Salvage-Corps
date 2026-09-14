//
//  FileStorage.swift
//  Salvage Corps
//
//  Helper genérico pra ler/escrever JSON no Documents directory.
//  Cada write faz backup automático do arquivo anterior. Reads têm
//  fallback pro backup se o principal falhar (corrupção, escrita
//  incompleta por app-kill).
//
//  Design pattern:
//  1. save → move current pra .backup, escreve novo current
//  2. load → tenta current, se falhar tenta .backup, senão nil
//  3. migrate → helper pra mover de UserDefaults pra file na 1ª execução
//

import Foundation

enum FileStorage {

    // MARK: - Paths

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private static func url(for filename: String) -> URL {
        documentsDirectory.appendingPathComponent(filename)
    }

    private static func backupURL(for filename: String) -> URL {
        documentsDirectory.appendingPathComponent(filename + ".backup")
    }

    // MARK: - Public API

    /// Serializa e escreve JSON no Documents/. Faz backup automático do
    /// arquivo anterior (se existir). Throws em caso de falha de I/O.
    static func save<T: Encodable>(_ value: T, to filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)

        let mainURL = url(for: filename)
        let backupPath = backupURL(for: filename)
        let fm = FileManager.default

        // 1. Se já existe main, move pra backup (substitui backup antigo)
        if fm.fileExists(atPath: mainURL.path) {
            if fm.fileExists(atPath: backupPath.path) {
                try? fm.removeItem(at: backupPath)
            }
            try? fm.moveItem(at: mainURL, to: backupPath)
        }

        // 2. Escreve novo main
        try data.write(to: mainURL, options: [.atomic])
    }

    /// Carrega JSON do Documents/. Tenta main primeiro, fallback pro backup.
    /// Retorna nil se ambos falharem ou não existirem.
    static func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        let mainURL = url(for: filename)
        let backupPath = backupURL(for: filename)
        let decoder = JSONDecoder()

        // Tenta main
        if let data = try? Data(contentsOf: mainURL),
           let value = try? decoder.decode(type, from: data) {
            return value
        }

        // Fallback pra backup
        if let data = try? Data(contentsOf: backupPath),
           let value = try? decoder.decode(type, from: data) {
            print("FileStorage: '\(filename)' corrupto, usando backup")
            // Restaura backup como novo main
            try? Data(contentsOf: backupPath).write(to: mainURL, options: [.atomic])
            return value
        }

        return nil
    }

    /// True se o save principal existe (mesmo que corrupto — pra migração).
    static func exists(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: filename).path)
    }

    /// Deleta save principal + backup. Usado pra reset total.
    static func delete(_ filename: String) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: url(for: filename))
        try? fm.removeItem(at: backupURL(for: filename))
    }

    // MARK: - Migration helper

    /// Tenta migrar dados de UserDefaults pra file. Chamado uma vez na
    /// inicialização de cada Store. Se o file JÁ existe, no-op. Se
    /// UserDefaults tem dado válido, migra.
    ///
    /// Retorna: valor migrado (se sucesso) OU nil (nada pra migrar).
    ///
    /// T precisa ser Codable (Encodable pra save + Decodable pra load).
    static func migrateFromUserDefaults<T: Codable>(
        _ type: T.Type,
        userDefaultsKey: String,
        toFilename filename: String
    ) -> T? {
        // Se o file já existe, não migra
        guard !exists(filename) else { return nil }

        // Se UserDefaults tem, tenta decodificar
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        guard let value = try? JSONDecoder().decode(type, from: data) else {
            print("FileStorage: falha ao decodificar '\(userDefaultsKey)' pra migração")
            return nil
        }

        // Escreve no file + remove do UserDefaults
        do {
            try save(value, to: filename)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            print("FileStorage: migrado '\(userDefaultsKey)' → '\(filename)'")
            return value
        } catch {
            print("FileStorage: falha na migração — \(error)")
            return nil
        }
    }
}
