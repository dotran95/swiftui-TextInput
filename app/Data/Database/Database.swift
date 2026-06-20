//
//  Database.swift
//  app
//
//  Created by dotn on 15/8/24.
//

import Foundation
import FMDB

enum CreatesTableSQL: String, CaseIterable {
    case apiResponse = "CREATE TABLE IF NOT EXISTS responses (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT UNIQUE, data BLOB)"
}

class DatabaseManager {
    static let shared = DatabaseManager()

    private let queue: FMDatabaseQueue

    private init() {
        // Initialize the database path
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = documentsDirectory.appendingPathComponent("database.sqlite").path

        // Initialize the database queue
        queue = FMDatabaseQueue(path: dbPath)!

        logger.debug("DB Path: \(dbPath)")

        createTable()
    }

    private func createTable() {
        queue.inDatabase { db in
            do {
                let querys = CreatesTableSQL.allCases
                for query in querys {
                    try db.executeUpdate(query.rawValue, values: nil)
                }
            } catch {
                print("Failed to create table: \(error.localizedDescription)")
            }
        }
    }

    func insertOrReplaceApiResponse(_ key: String, data: Data) {
        queue.inTransaction { db, rollback in
            do {
                let insertSQL = "INSERT OR REPLACE INTO responses (key, data) VALUES (?, ?)"
                try db.executeUpdate(insertSQL, values: [key, data])
            } catch {
                logger.debug("DB InsertOrReplace Failed to insert data: \(error.localizedDescription)")
                rollback.pointee = true  // Rollback the transaction in case of error
            }
        }
    }

    func selectApiResponse(_ key: String) {
        queue.inTransaction { db, rollback in
            do {
                let query = "SELECT INTO responses WHERE key=?"
                try db.executeQuery(query, values: [key])
            } catch {
                logger.debug("DB selectApiResponse Failed to insert data: \(error.localizedDescription)")
                rollback.pointee = true  // Rollback the transaction in case of error
            }
        }
    }

}
