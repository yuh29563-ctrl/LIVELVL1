import Foundation
import SwiftData

enum Recurrence: String, CaseIterable, Codable, Identifiable { case once, daily, weekly; var id: String { rawValue }; var title: String { ["一次性","每天","每周"][Recurrence.allCases.firstIndex(of: self)!] } }
enum GrowthEngine {
    static func recommendedXP(minutes: Int, difficulty: Int) -> Int {
        let safeMinutes = Double(max(5, minutes))
        let safeDifficulty = Double(max(1, difficulty))
        let raw = safeMinutes * (0.6 + safeDifficulty * 0.2)
        return max(5, Int((raw / 5).rounded()) * 5)
    }
    static func level(for xp: Int) -> Int {
        let safeXP = max(0, xp)
        guard safeXP >= 200 else { return 0 }
        return 1 + (safeXP - 200) / 2_000
    }

    static func xpInCurrentLevel(for xp: Int) -> Int {
        let safeXP = max(0, xp)
        guard safeXP >= 200 else { return safeXP }
        return (safeXP - 200) % 2_000
    }

    static func xpNeededForNextLevel(for xp: Int) -> Int {
        level(for: xp) == 0 ? 200 : 2_000
    }

    static func progressToNextLevel(for xp: Int) -> Double {
        Double(xpInCurrentLevel(for: xp)) / Double(xpNeededForNextLevel(for: xp))
    }
}
@Model final class Item { var id: UUID; var title: String; var dimensionRaw: String; var minutes: Int; var difficulty: Int; var xp: Int; var recurrenceRaw: String; var createdAt: Date; init(title: String, dimension: LifeDimension, minutes: Int, difficulty: Int, xp: Int, recurrence: Recurrence) { id = UUID(); self.title = title; dimensionRaw = dimension.rawValue; self.minutes = minutes; self.difficulty = difficulty; self.xp = xp; recurrenceRaw = recurrence.rawValue; createdAt = .now }; var dimension: LifeDimension { LifeDimension(rawValue: dimensionRaw) ?? .learning } }
@Model final class Progress { var totalXP: Int; var onboardingCompleted: Bool; init(totalXP: Int = 0, onboardingCompleted: Bool = true) { self.totalXP = totalXP; self.onboardingCompleted = onboardingCompleted }; var level: Int { GrowthEngine.level(for: totalXP) } }
@Model final class Completion {
    var id: UUID?
    var itemID: UUID
    var date: Date
    var xp: Int
    var dimensionRaw: String?
    var durationMinutes: Int?
    var taskTitle: String?

    init(itemID: UUID, xp: Int, dimension: LifeDimension? = nil,
         durationMinutes: Int? = nil, taskTitle: String? = nil, date: Date = .now) {
        id = UUID()
        self.itemID = itemID
        self.xp = xp
        self.dimensionRaw = dimension?.rawValue
        self.durationMinutes = durationMinutes
        self.taskTitle = taskTitle
        self.date = date
    }

    var recordedDimension: LifeDimension? {
        dimensionRaw.flatMap(LifeDimension.init(rawValue:))
    }

    func stateActivity(fallbackItem: Item?) -> DimensionActivityRecord? {
        guard let dimension = recordedDimension
                ?? fallbackItem?.dimension else { return nil }
        return DimensionActivityRecord(
            dimension: dimension,
            taskTitle: taskTitle ?? fallbackItem?.title ?? "已完成的行动",
            date: date,
            xp: xp
        )
    }
}
