import Testing
@testable import LIVELVL

@MainActor
struct TodayJournalEntryTests {
    @Test func journalEntryKeepsTheApprovedCopyAndAccessibleHitTarget() {
        let presentation = TodayJournalEntryPresentation()

        #expect(presentation.title == "THE NOTE")
        #expect(presentation.subtitle == "记录今天留下的痕迹")
        #expect(presentation.accessibilityLabel == "日记本，记录今天留下的痕迹")
        #expect(presentation.accessibilityIdentifier == "today-journal-entry")
        #expect(presentation.minimumTapHeight >= 44)
    }

    @Test func journalEntryForwardsItsSingleOpenAction() {
        var didOpen = false
        let entry = TodayJournalEntryView {
            didOpen = true
        }

        entry.activate()

        #expect(didOpen)
    }
}
