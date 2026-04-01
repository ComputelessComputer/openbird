import Testing
@testable import OpenbirdApp

struct TodayTimelineModeTests {
    @Test func offersTopicAndTimelineWhenBothRepresentationsExist() {
        let modes = TodayTimelineMode.availableModes(
            hasJournalContent: true,
            hasTimelineItems: true
        )

        #expect(modes == [.topic, .timeline])
    }

    @Test func fallsBackToTimelineWhenTopicSelectionIsUnavailable() {
        let selectedMode = TodayTimelineMode.resolvedSelection(
            .topic,
            hasJournalContent: false,
            hasTimelineItems: true
        )

        #expect(selectedMode == .timeline)
    }

    @Test func returnsNoSelectionWhenNothingCanBeShown() {
        let selectedMode = TodayTimelineMode.resolvedSelection(
            .topic,
            hasJournalContent: false,
            hasTimelineItems: false
        )

        #expect(selectedMode == nil)
    }
}
