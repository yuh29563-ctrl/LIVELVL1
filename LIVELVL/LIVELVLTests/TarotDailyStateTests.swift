import Foundation
import Observation
import SwiftData
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct TarotDailyStateTests {
    @Test func dailyPresentationClearsYesterdayRevealAtTheDayBoundary() {
        var presentation = TarotDailyPresentationState()
        presentation.begin(dayIdentifier: "2026-09-16")
        presentation.choose(index: 1, on: "2026-09-16")
        presentation.reveal(on: "2026-09-16")
        presentation.showReading(on: "2026-09-16")

        presentation.begin(dayIdentifier: "2026-09-17")

        #expect(presentation.chosenIndex == nil)
        #expect(!presentation.isCardRevealed)
        #expect(!presentation.showsReading)
    }

    @Test func delayedRevealFromYesterdayCannotChangeTodaysPresentation() {
        var presentation = TarotDailyPresentationState()
        presentation.begin(dayIdentifier: "2026-09-16")
        presentation.choose(index: 1, on: "2026-09-16")

        presentation.begin(dayIdentifier: "2026-09-17")
        presentation.reveal(on: "2026-09-16")
        presentation.showReading(on: "2026-09-16")

        #expect(presentation.chosenIndex == nil)
        #expect(!presentation.isCardRevealed)
        #expect(!presentation.showsReading)
    }

    @Test func dayClockPublishesANewIdentifierAfterCrossingLocalMidnight() async {
        let calendar = makeCalendar()
        var simulatedNow = makeDate(2026, 9, 16, 23, 59)
        let clock = TarotDayClock(calendar: calendar, now: { simulatedNow })

        await confirmation("day identifier observation changes") { changed in
            withObservationTracking {
                _ = clock.dayIdentifier
            } onChange: {
                changed()
            }

            simulatedNow = makeDate(2026, 9, 17, 0, 1)
            clock.refresh()
        }

        #expect(clock.dayIdentifier == "2026-09-17")
    }

    @Test func dayClockSchedulesTheRefreshAtTheNextLocalMidnight() {
        let calendar = makeCalendar()

        let boundary = TarotDayClock.nextDayBoundary(
            after: makeDate(2026, 9, 16, 23, 59),
            calendar: calendar
        )

        #expect(boundary == makeDate(2026, 9, 17, 0))
    }

    @Test func cardFlipMovesForwardFromFaceToBackAndBackToFace() {
        var flip = TarotCardFlipState()

        #expect(!flip.showsBack)
        #expect(flip.targetAngle == 0)
        let beganFirstFlip = flip.begin()
        #expect(beganFirstFlip)
        #expect(flip.targetAngle == 180)

        flip.complete()
        #expect(flip.showsBack)
        #expect(flip.targetAngle == 180)
        let beganSecondFlip = flip.begin()
        #expect(beganSecondFlip)
        #expect(flip.targetAngle == 360)

        flip.complete()
        #expect(!flip.showsBack)
        #expect(flip.targetAngle == 360)
    }

    @Test func cardFlipIgnoresAnotherTapUntilTheCurrentTurnCompletes() {
        var flip = TarotCardFlipState()

        let beganFirstFlip = flip.begin()
        let beganOverlappingFlip = flip.begin()
        #expect(beganFirstFlip)
        #expect(!beganOverlappingFlip)
        #expect(flip.targetAngle == 180)

        flip.complete()
        let beganSecondFlip = flip.begin()
        #expect(beganSecondFlip)
        #expect(flip.targetAngle == 360)
    }

    @Test func cardFlipGatesHitTestingWithoutChangingTheCardsVisualState() {
        var flip = TarotCardFlipState()

        #expect(flip.acceptsInput)
        _ = flip.begin()
        #expect(!flip.acceptsInput)
        flip.complete()
        #expect(flip.acceptsInput)
    }

    @Test func cardFlipShadowConcentratesAroundTheMidpointAndSettlesEarly() {
        #expect(TarotCardFlipEffects.shadowPulse(at: 0) == 0)
        #expect(TarotCardFlipEffects.shadowPulse(at: 90) == 1)
        #expect(TarotCardFlipEffects.shadowPulse(at: 150) < 0.15)
        #expect(TarotCardFlipEffects.shadowPulse(at: 180) == 0)
    }

    @Test func catalogContainsTheTraditionalTwentyTwoMajorArcana() {
        #expect(TarotCatalog.cards.map(\.number) == Array(0...21))
        #expect(TarotCatalog.cards.map(\.name) == [
            "愚者", "魔术师", "女祭司", "皇后", "皇帝", "教皇", "恋人", "战车",
            "力量", "隐者", "命运之轮", "正义", "倒吊人", "死神", "节制", "恶魔",
            "高塔", "星星", "月亮", "太阳", "审判", "世界",
        ])
    }

    @Test func everyCardHasCompleteUprightAndReversedReadings() {
        for card in TarotCatalog.cards {
            for orientation in TarotOrientation.allCases {
                let reading = card.reading(for: orientation)
                #expect(!reading.theme.isEmpty)
                #expect(!reading.attention.isEmpty)
                #expect(!reading.action.isEmpty)
            }
        }
    }

    @Test func everyMajorArcanaCardAndTheOriginalBackHaveBundledArtwork() {
        #expect(UIImage(named: "TarotRWSBack") != nil)
        for card in TarotCatalog.cards {
            #expect(UIImage(named: card.artworkAssetName) != nil)
        }
    }

    @Test func dailySpreadContainsThreeDistinctCards() {
        var random = SeededRandomNumberGenerator(seed: 1)
        let calendar = makeCalendar()

        let state = TarotDailyService.makeState(
            now: makeDate(2026, 9, 16, 9),
            calendar: calendar,
            random: &random
        )

        #expect(state.candidateCardIDs.count == 3)
        #expect(Set(state.candidateCardIDs).count == 3)
        #expect(state.candidateOrientations.count == 3)
        #expect(state.selectedIndex == nil)
    }

    @Test func selectingACardLocksTheFirstResult() {
        var random = SeededRandomNumberGenerator(seed: 1)
        let calendar = makeCalendar()
        let selectedAt = makeDate(2026, 9, 16, 10)
        let state = TarotDailyService.makeState(
            now: makeDate(2026, 9, 16, 9),
            calendar: calendar,
            random: &random
        )

        #expect(TarotDailyService.select(index: 1, at: selectedAt, in: state))
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAt == selectedAt)

        #expect(!TarotDailyService.select(
            index: 2,
            at: makeDate(2026, 9, 16, 11),
            in: state
        ))
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAt == selectedAt)
    }

    @Test func sameLocalDayKeepsTheExistingSpread() {
        var random = SeededRandomNumberGenerator(seed: 1)
        let calendar = makeCalendar()
        let state = TarotDailyService.makeState(
            now: makeDate(2026, 9, 16, 8),
            calendar: calendar,
            random: &random
        )
        let originalIDs = state.candidateCardIDs

        let didReset = TarotDailyService.resetIfNeeded(
            state,
            now: makeDate(2026, 9, 16, 23),
            calendar: calendar,
            random: &random
        )

        #expect(!didReset)
        #expect(state.candidateCardIDs == originalIDs)
    }

    @Test func nextLocalDayReplacesTheSpreadAndClearsTheSelection() {
        var firstRandom = SeededRandomNumberGenerator(seed: 1)
        var nextRandom = SeededRandomNumberGenerator(seed: 9)
        let calendar = makeCalendar()
        let state = TarotDailyService.makeState(
            now: makeDate(2026, 9, 16, 23),
            calendar: calendar,
            random: &firstRandom
        )
        _ = TarotDailyService.select(
            index: 0,
            at: makeDate(2026, 9, 16, 23, 30),
            in: state
        )
        let previousIDs = state.candidateCardIDs

        let didReset = TarotDailyService.resetIfNeeded(
            state,
            now: makeDate(2026, 9, 17, 0, 1),
            calendar: calendar,
            random: &nextRandom
        )

        #expect(didReset)
        #expect(state.dayIdentifier == "2026-09-17")
        #expect(state.selectedIndex == nil)
        #expect(state.selectedAt == nil)
        #expect(state.candidateCardIDs != previousIDs)
    }

    @Test func persistedStateIsCreatedOnceAndReusedOnTheSameDay() throws {
        let container = try ModelContainer(
            for: Schema([TarotDailyState.self]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let calendar = makeCalendar()
        var random = SeededRandomNumberGenerator(seed: 4)

        let first = try TarotDailyService.loadOrCreateState(
            in: context,
            now: makeDate(2026, 9, 16, 8),
            calendar: calendar,
            random: &random
        )
        let originalIDs = first.candidateCardIDs
        let second = try TarotDailyService.loadOrCreateState(
            in: context,
            now: makeDate(2026, 9, 16, 22),
            calendar: calendar,
            random: &random
        )

        #expect(first === second)
        #expect(second.candidateCardIDs == originalIDs)
        #expect(try context.fetch(FetchDescriptor<TarotDailyState>()).count == 1)
    }

    @Test func persistedSelectionSurvivesARefetchAndDoesNotCreateACollectible() throws {
        let container = try ModelContainer(
            for: Schema([TarotDailyState.self, OwnedCollectible.self]),
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let calendar = makeCalendar()
        var random = SeededRandomNumberGenerator(seed: 7)
        let state = try TarotDailyService.loadOrCreateState(
            in: context,
            now: makeDate(2026, 9, 16, 8),
            calendar: calendar,
            random: &random
        )

        #expect(try TarotDailyService.select(
            index: 2,
            at: makeDate(2026, 9, 16, 9),
            in: state,
            context: context
        ))

        let fetched = try #require(context.fetch(FetchDescriptor<TarotDailyState>()).first)
        #expect(fetched.selectedIndex == 2)
        #expect(try context.fetch(FetchDescriptor<OwnedCollectible>()).isEmpty)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0
    ) -> Date {
        makeCalendar().date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
