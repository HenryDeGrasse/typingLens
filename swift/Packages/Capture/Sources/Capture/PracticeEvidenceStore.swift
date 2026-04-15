import Core
import Foundation
import os
import SQLite3

final class PracticeEvidenceStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storeURL: URL?
    private var database: OpaquePointer?
    private(set) var lastPersistenceError: String?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        (self.encoder, self.decoder) = Self.makeCoders()

        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            self.storeURL = nil
            self.lastPersistenceError = "Application Support directory unavailable. Practice evidence will not be saved."
            Self.logger.error("Application Support directory unavailable; evidence persistence disabled.")
            return
        }

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ai.gauntlet.typinglens"
        let folderURL = applicationSupportDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        self.storeURL = folderURL.appendingPathComponent("practice-evidence.sqlite3", isDirectory: false)

        bootstrap(folderURL: folderURL)
    }

    init(storeURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        (self.encoder, self.decoder) = Self.makeCoders()
        self.storeURL = storeURL
        bootstrap(folderURL: storeURL.deletingLastPathComponent())
    }

    private static func makeCoders() -> (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (encoder, decoder)
    }

    private func bootstrap(folderURL: URL) {
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try openDatabase()
            try migrate()
        } catch {
            recordPersistenceError("Could not initialize evidence store: \(Self.message(for: error))", error: error)
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    var persistenceDescription: String {
        storeURL?.path ?? "(unavailable)"
    }

    func ensureModelVersionStamp(_ stamp: ModelVersionStamp) {
        perform(label: "ensureModelVersionStamp") {
            try insert(
                sql: """
                INSERT OR IGNORE INTO model_version_stamps (
                    id, created_at, payload_json
                ) VALUES (?, ?, ?);
                """,
                bindings: [
                    .text(stamp.id),
                    .text(Self.iso8601(stamp.createdAt)),
                    .text(encoded(stamp))
                ]
            )
        }
    }

    func appendRecommendationDecision(_ record: RecommendationDecisionRecord) {
        perform(label: "appendRecommendationDecision") {
            try insert(
                sql: """
                INSERT INTO recommendation_decisions (
                    id, created_at, selected_skill_id, selected_weakness, payload_json
                ) VALUES (?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(record.id.uuidString),
                    .text(Self.iso8601(record.createdAt)),
                    .text(record.selectedSkillID),
                    .text(record.selectedWeakness.rawValue),
                    .text(encoded(record))
                ]
            )
        }
    }

    func appendPracticeSession(_ record: PracticeSessionSummaryRecord) {
        perform(label: "appendPracticeSession") {
            try insert(
                sql: """
                INSERT INTO practice_sessions (
                    id, started_at, ended_at, selected_skill_id, selected_weakness, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(record.id.uuidString),
                    .text(Self.iso8601(record.startedAt)),
                    .text(Self.iso8601(record.endedAt)),
                    .text(record.selectedSkillID),
                    .text(record.selectedWeakness.rawValue),
                    .text(encoded(record))
                ]
            )
        }
    }

    func appendImmediateEvaluations(_ records: [ImmediateEvaluationRecord]) {
        perform(label: "appendImmediateEvaluations") {
            for record in records {
                try insert(
                    sql: """
                    INSERT INTO immediate_evaluations (
                        id, session_id, evaluation_type, inserted_at, payload_json
                    ) VALUES (?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(record.id.uuidString),
                        .text(record.sessionID.uuidString),
                        .text(record.evaluationType.rawValue),
                        .text(Self.iso8601(Date())),
                        .text(encoded(record))
                    ]
                )
            }
        }
    }

    func appendPassiveSlices(_ records: [PassiveActiveSliceRecord]) {
        perform(label: "appendPassiveSlices") {
            for record in records {
                try insert(
                    sql: """
                    INSERT INTO passive_active_slices (
                        id, started_at, ended_at, keyboard_layout_id, keyboard_device_class, payload_json
                    ) VALUES (?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(record.id.uuidString),
                        .text(Self.iso8601(record.startedAt)),
                        .text(Self.iso8601(record.endedAt)),
                        .text(record.keyboardLayoutID),
                        .text(record.keyboardDeviceClass),
                        .text(encoded(record))
                    ]
                )
            }
        }
    }

    func upsertTransferTicket(_ record: PassiveTransferTicketRecord) {
        perform(label: "upsertTransferTicket") {
            try insert(
                sql: """
                INSERT OR REPLACE INTO passive_transfer_tickets (
                    id, session_id, created_at, status, payload_json
                ) VALUES (?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(record.id.uuidString),
                    .text(record.sessionID.uuidString),
                    .text(Self.iso8601(record.createdAt)),
                    .text(record.status.rawValue),
                    .text(encoded(record))
                ]
            )
        }
    }

    func appendTransferResult(_ record: PassiveTransferResultRecord) {
        perform(label: "appendTransferResult") {
            try insert(
                sql: """
                INSERT INTO passive_transfer_results (
                    id, ticket_id, resolved_at, payload_json
                ) VALUES (?, ?, ?, ?);
                """,
                bindings: [
                    .text(record.id.uuidString),
                    .text(record.ticketID.uuidString),
                    .text(Self.iso8601(record.resolvedAt)),
                    .text(encoded(record))
                ]
            )
        }
    }

    func appendLearnerStateUpdate(_ record: LearnerStateUpdateRecord) {
        perform(label: "appendLearnerStateUpdate") {
            try insert(
                sql: """
                INSERT INTO learner_state_updates (
                    id, created_at, skill_id, source_type, payload_json
                ) VALUES (?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(record.id.uuidString),
                    .text(Self.iso8601(record.createdAt)),
                    .text(record.skillID),
                    .text(record.sourceType.rawValue),
                    .text(encoded(record))
                ]
            )
        }
    }

    func fetchPracticeHistory(limit: Int = 8) -> PracticeHistorySnapshot {
        let pendingTransferTickets: [PassiveTransferTicketRecord] = fetchMany(
            sql: "SELECT payload_json FROM passive_transfer_tickets WHERE status = ? ORDER BY created_at DESC LIMIT ?;",
            bindings: [.text(PassiveTransferTicketStatus.pending.rawValue), .integer(Int64(limit))]
        )

        return PracticeHistorySnapshot(
            modelVersionStamp: fetchSingle(from: "model_version_stamps", orderBy: "created_at DESC"),
            recentDecisions: fetchMany(from: "recommendation_decisions", orderBy: "created_at DESC", limit: limit),
            recentSessions: fetchMany(from: "practice_sessions", orderBy: "ended_at DESC", limit: limit),
            recentEvaluations: fetchMany(from: "immediate_evaluations", orderBy: "inserted_at DESC", limit: limit * 2),
            pendingTransferTickets: pendingTransferTickets,
            pendingTransferProgress: pendingTransferTickets.map(transferProgress(for:)),
            recentTransferResults: fetchMany(from: "passive_transfer_results", orderBy: "resolved_at DESC", limit: limit),
            recentStateUpdates: fetchMany(from: "learner_state_updates", orderBy: "created_at DESC", limit: limit)
        )
    }

    func recentPracticeSessionCount(skillID: String) -> Int {
        scalarInt(
            sql: "SELECT COUNT(*) FROM practice_sessions WHERE selected_skill_id = ?;",
            bindings: [.text(skillID)]
        )
    }

    func transferProgress(for ticket: PassiveTransferTicketRecord) -> PassiveTransferProgressSnapshot {
        let compatibleSliceCount = scalarInt(
            sql: """
            SELECT COUNT(*)
            FROM passive_active_slices
            WHERE started_at >= ?
              AND keyboard_layout_id = ?
              AND keyboard_device_class = ?;
            """,
            bindings: [
                .text(Self.iso8601(ticket.earliestEligibleAt)),
                .text(ticket.keyboardLayoutID),
                .text(ticket.keyboardDeviceClass)
            ]
        )

        let incompatibleSliceCount = scalarInt(
            sql: """
            SELECT COUNT(*)
            FROM passive_active_slices
            WHERE started_at >= ?
              AND NOT (keyboard_layout_id = ? AND keyboard_device_class = ?);
            """,
            bindings: [
                .text(Self.iso8601(ticket.earliestEligibleAt)),
                .text(ticket.keyboardLayoutID),
                .text(ticket.keyboardDeviceClass)
            ]
        )

        return PassiveTransferProgressSnapshot(
            ticketID: ticket.id,
            skillID: ticket.skillID,
            weakness: ticket.weakness,
            status: ticket.status,
            compatibleSliceCount: compatibleSliceCount,
            requiredSliceCount: ticket.requiredPostSliceCount,
            incompatibleSliceCount: incompatibleSliceCount,
            earliestEligibleAt: ticket.earliestEligibleAt,
            expiresAt: ticket.expiresAt,
            keyboardLayoutID: ticket.keyboardLayoutID,
            keyboardDeviceClass: ticket.keyboardDeviceClass
        )
    }

    func appliedStateOverlay() -> [String: SkillDimensionState] {
        let updates: [LearnerStateUpdateRecord] = fetchMany(
            sql: "SELECT payload_json FROM learner_state_updates ORDER BY created_at ASC;",
            bindings: []
        )

        var overlay: [String: SkillDimensionState] = [:]
        for update in updates where update.appliedToRecommendations {
            var current = overlay[update.skillID] ?? SkillDimensionState()
            current.control += update.deltaControl
            current.consistency += update.deltaConsistency
            current.automaticity += update.deltaAutomaticity
            current.stability += update.deltaStability
            overlay[update.skillID] = current
        }
        return overlay
    }

    func recentPassiveSlices(
        endingBefore date: Date,
        keyboardLayoutID: String,
        keyboardDeviceClass: String,
        limit: Int
    ) -> [PassiveActiveSliceRecord] {
        let rows: [PassiveActiveSliceRecord] = fetchMany(
            sql: """
            SELECT payload_json
            FROM passive_active_slices
            WHERE ended_at < ?
              AND (keyboard_layout_id = ? OR ? = 'unknown')
              AND (keyboard_device_class = ? OR ? = 'unknown')
            ORDER BY ended_at DESC
            LIMIT ?;
            """,
            bindings: [
                .text(Self.iso8601(date)),
                .text(keyboardLayoutID),
                .text(keyboardLayoutID),
                .text(keyboardDeviceClass),
                .text(keyboardDeviceClass),
                .integer(Int64(limit))
            ]
        )
        return rows.reversed()
    }

    func recentPassiveSlices(
        startingAfter date: Date,
        keyboardLayoutID: String,
        keyboardDeviceClass: String,
        limit: Int
    ) -> [PassiveActiveSliceRecord] {
        fetchMany(
            sql: """
            SELECT payload_json
            FROM passive_active_slices
            WHERE started_at >= ?
              AND (keyboard_layout_id = ? OR ? = 'unknown')
              AND (keyboard_device_class = ? OR ? = 'unknown')
            ORDER BY started_at ASC
            LIMIT ?;
            """,
            bindings: [
                .text(Self.iso8601(date)),
                .text(keyboardLayoutID),
                .text(keyboardLayoutID),
                .text(keyboardDeviceClass),
                .text(keyboardDeviceClass),
                .integer(Int64(limit))
            ]
        )
    }

    private func perform(label: StaticString, _ body: () throws -> Void) {
        guard database != nil else { return }
        do {
            try body()
        } catch {
            recordPersistenceError("\(label) failed: \(Self.message(for: error))", error: error)
        }
    }

    private func recordPersistenceError(_ description: String, error: Error) {
        lastPersistenceError = description
        Self.logger.error("\(description, privacy: .public)")
    }

    private static func message(for error: Error) -> String {
        if let storeError = error as? SQLiteStoreError {
            return storeError.message
        }
        return error.localizedDescription
    }

    private func fetchSingle<T: Decodable>(from table: String, orderBy: String) -> T? {
        let values: [T] = fetchMany(from: table, orderBy: orderBy, limit: 1)
        return values.first
    }

    private func scalarInt(sql: String, bindings: [Binding]) -> Int {
        guard let database else { return 0 }
        guard let statement = prepare(database: database, sql: sql) else { return 0 }
        defer { sqlite3_finalize(statement) }
        bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func fetchMany<T: Decodable>(from table: String, orderBy: String, limit: Int) -> [T] {
        fetchMany(
            sql: "SELECT payload_json FROM \(table) ORDER BY \(orderBy) LIMIT ?;",
            bindings: [.integer(Int64(limit))]
        )
    }

    private func fetchMany<T: Decodable>(sql: String, bindings: [Binding]) -> [T] {
        guard let database else { return [] }
        guard let statement = prepare(database: database, sql: sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(bindings, to: statement)

        var values: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 0) else { continue }
            let payload = String(cString: text)
            guard let data = payload.data(using: .utf8),
                  let decoded = try? decoder.decode(T.self, from: data) else {
                continue
            }
            values.append(decoded)
        }
        return values
    }

    private func openDatabase() throws {
        guard let storeURL else {
            throw SQLiteStoreError.openFailed(message: "Store URL unavailable.")
        }

        var handle: OpaquePointer?
        let status = sqlite3_open(storeURL.path, &handle)
        if status != SQLITE_OK {
            // sqlite3_open may populate the handle even on failure; capture errmsg before closing.
            let message: String
            if let handle {
                message = String(cString: sqlite3_errmsg(handle))
                sqlite3_close(handle)
            } else {
                message = "sqlite3_open returned status \(status)"
            }
            throw SQLiteStoreError.openFailed(message: message)
        }
        self.database = handle
    }

    private func migrate() throws {
        try exec(
            """
            CREATE TABLE IF NOT EXISTS model_version_stamps (
                id TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS recommendation_decisions (
                id TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                selected_skill_id TEXT NOT NULL,
                selected_weakness TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_recommendation_decisions_created_at ON recommendation_decisions(created_at DESC);

            CREATE TABLE IF NOT EXISTS practice_sessions (
                id TEXT PRIMARY KEY,
                started_at TEXT NOT NULL,
                ended_at TEXT NOT NULL,
                selected_skill_id TEXT NOT NULL,
                selected_weakness TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_practice_sessions_ended_at ON practice_sessions(ended_at DESC);

            CREATE TABLE IF NOT EXISTS immediate_evaluations (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                evaluation_type TEXT NOT NULL,
                inserted_at TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_immediate_evaluations_inserted_at ON immediate_evaluations(inserted_at DESC);

            CREATE TABLE IF NOT EXISTS passive_active_slices (
                id TEXT PRIMARY KEY,
                started_at TEXT NOT NULL,
                ended_at TEXT NOT NULL,
                keyboard_layout_id TEXT NOT NULL,
                keyboard_device_class TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_passive_active_slices_ended_at ON passive_active_slices(ended_at DESC);

            CREATE TABLE IF NOT EXISTS passive_transfer_tickets (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_passive_transfer_tickets_status ON passive_transfer_tickets(status, created_at DESC);

            CREATE TABLE IF NOT EXISTS passive_transfer_results (
                id TEXT PRIMARY KEY,
                ticket_id TEXT NOT NULL,
                resolved_at TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_passive_transfer_results_resolved_at ON passive_transfer_results(resolved_at DESC);

            CREATE TABLE IF NOT EXISTS learner_state_updates (
                id TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                skill_id TEXT NOT NULL,
                source_type TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_learner_state_updates_created_at ON learner_state_updates(created_at DESC);
            """
        )
    }

    private func exec(_ sql: String) throws {
        guard let database else { return }
        if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
            throw SQLiteStoreError.execFailed(message: String(cString: sqlite3_errmsg(database)))
        }
    }

    private func insert(sql: String, bindings: [Binding]) throws {
        guard let database else { return }
        guard let statement = prepare(database: database, sql: sql) else {
            throw SQLiteStoreError.prepareFailed(message: String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        bind(bindings, to: statement)

        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteStoreError.stepFailed(message: String(cString: sqlite3_errmsg(database)))
        }
    }

    private func prepare(database: OpaquePointer, sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        return statement
    }

    private func bind(_ bindings: [Binding], to statement: OpaquePointer?) {
        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch binding {
            case let .text(value):
                sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
            case let .integer(value):
                sqlite3_bind_int64(statement, position, value)
            case let .double(value):
                sqlite3_bind_double(statement, position, value)
            case .null:
                sqlite3_bind_null(statement, position)
            }
        }
    }

    private func encoded<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    // ISO8601DateFormatter is documented as thread-safe, but ObjC inheritance
    // prevents Swift from inferring Sendable. Static is read-only after init.
    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func iso8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    private static let logger = Logger(subsystem: "ai.gauntlet.typinglens", category: "PracticeEvidenceStore")
}

private enum Binding {
    case text(String)
    case integer(Int64)
    case double(Double)
    case null
}

private enum SQLiteStoreError: Error {
    case openFailed(message: String)
    case execFailed(message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)

    var message: String {
        switch self {
        case let .openFailed(message),
             let .execFailed(message),
             let .prepareFailed(message),
             let .stepFailed(message):
            return message
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
