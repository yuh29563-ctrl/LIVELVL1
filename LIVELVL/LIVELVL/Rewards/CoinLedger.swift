import Foundation
import SwiftData

enum CoinDisplayFormatter {
    static func text(forCoinUnits units: Int) -> String {
        String(
            format: "%.1f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(max(0, units)) / 10.0
        )
    }
}

@MainActor
enum CoinLedgerService {
    static func balance(in context: ModelContext) throws -> Int {
        let total = try context.fetch(FetchDescriptor<CoinTransaction>())
            .reduce(0) { $0 + $1.amountCoinUnits }
        guard total >= 0 else { throw CoinLedgerError.negativeBalance }
        return total
    }

    static func ensureLegacyXPImported(
        progress: Progress,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let transactions = try context.fetch(FetchDescriptor<CoinTransaction>())
        guard !transactions.contains(where: { $0.operationKey == "legacy-xp-import" }) else {
            return
        }
        let importedXP = max(0, progress.totalXP)
        context.insert(CoinTransaction(
            operationKey: "legacy-xp-import",
            kind: .legacyImport,
            amountCoinUnits: importedXP,
            requestedCoinUnits: importedXP,
            sourceID: nil,
            createdAt: now,
            note: "首次导入既有 XP"
        ))
        try save(context)
    }

    static func awardTask(
        completion: Completion,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let operationKey = "task-earned:\(sourceKey(for: completion))"
        let transactions = try context.fetch(FetchDescriptor<CoinTransaction>())
        guard !transactions.contains(where: { $0.operationKey == operationKey }) else {
            return
        }
        let amount = max(0, completion.xp)
        context.insert(CoinTransaction(
            operationKey: operationKey,
            kind: .taskEarned,
            amountCoinUnits: amount,
            requestedCoinUnits: amount,
            sourceID: completion.id,
            createdAt: now,
            note: "完成任务获得金币"
        ))
        try save(context)
    }

    static func reverseTask(
        completion: Completion,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let operationKey = "task-revoked:\(sourceKey(for: completion))"
        let transactions = try context.fetch(FetchDescriptor<CoinTransaction>())
        guard !transactions.contains(where: { $0.operationKey == operationKey }) else {
            return
        }
        let requested = max(0, completion.xp)
        let actual = min(requested, try balance(in: context))
        context.insert(CoinTransaction(
            operationKey: operationKey,
            kind: .taskRevoked,
            amountCoinUnits: -actual,
            requestedCoinUnits: requested,
            sourceID: completion.id,
            createdAt: now,
            note: "撤销任务扣回金币"
        ))
        try save(context)
    }

    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func sourceKey(for completion: Completion) -> String {
        if let id = completion.id {
            return id.uuidString
        }
        return "legacy-\(completion.itemID.uuidString)-\(completion.date.timeIntervalSince1970)"
    }
}
