import Foundation
import SwiftData

enum LifeDimension: String, CaseIterable, Codable, Identifiable { case health, learning, career, finance, relationships, interests; var id: String { rawValue }; var title: String { ["健康","学习","事业","财务","关系","兴趣"][LifeDimension.allCases.firstIndex(of: self)!] } }
enum Recurrence: String, CaseIterable, Codable, Identifiable { case once, daily, weekly; var id: String { rawValue }; var title: String { ["一次性","每天","每周"][Recurrence.allCases.firstIndex(of: self)!] } }
enum GrowthEngine {
    static func recommendedXP(minutes: Int, difficulty: Int) -> Int {
        let safeMinutes = Double(max(5, minutes))
        let safeDifficulty = Double(max(1, difficulty))
        let raw = safeMinutes * (0.6 + safeDifficulty * 0.2)
        return max(5, Int((raw / 5).rounded()) * 5)
    }
    static func level(for xp: Int) -> Double {
        let value = Double(max(0, xp)) / 10.0
        return (value * 10).rounded() / 10
    }
}
@Model final class Item { var id: UUID; var title: String; var dimensionRaw: String; var minutes: Int; var difficulty: Int; var xp: Int; var recurrenceRaw: String; var createdAt: Date; init(title: String, dimension: LifeDimension, minutes: Int, difficulty: Int, xp: Int, recurrence: Recurrence) { id = UUID(); self.title = title; dimensionRaw = dimension.rawValue; self.minutes = minutes; self.difficulty = difficulty; self.xp = xp; recurrenceRaw = recurrence.rawValue; createdAt = .now }; var dimension: LifeDimension { LifeDimension(rawValue: dimensionRaw) ?? .learning } }
@Model final class Progress { var totalXP: Int; var onboardingCompleted: Bool; init(totalXP: Int = 0, onboardingCompleted: Bool = true) { self.totalXP = totalXP; self.onboardingCompleted = onboardingCompleted }; var level: Double { GrowthEngine.level(for: totalXP) } }
@Model final class Completion { var itemID: UUID; var date: Date; var xp: Int; init(itemID: UUID, xp: Int) { self.itemID = itemID; self.xp = xp; date = .now } }
