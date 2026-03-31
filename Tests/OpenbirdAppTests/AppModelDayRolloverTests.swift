import Foundation
import Testing
@testable import OpenbirdApp

struct AppModelDayRolloverTests {
    @Test func advancesSelectedDayWhenItWasFollowingToday() {
        let calendar = makeCalendar()
        let previousCurrentDay = makeDate(year: 2026, month: 3, day: 30, hour: 0, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 3, day: 30, hour: 18, minute: 45, calendar: calendar)
        let now = makeDate(year: 2026, month: 3, day: 31, hour: 0, minute: 1, calendar: calendar)

        let advancedDay = AppModel.autoAdvancedSelectedDay(
            from: selectedDay,
            previousCurrentDay: previousCurrentDay,
            now: now,
            calendar: calendar
        )

        #expect(advancedDay == makeDate(year: 2026, month: 3, day: 31, hour: 0, minute: 0, calendar: calendar))
    }

    @Test func leavesHistoricalSelectionAloneAcrossMidnight() {
        let calendar = makeCalendar()
        let previousCurrentDay = makeDate(year: 2026, month: 3, day: 30, hour: 0, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 3, day: 29, hour: 12, minute: 0, calendar: calendar)
        let now = makeDate(year: 2026, month: 3, day: 31, hour: 0, minute: 1, calendar: calendar)

        let advancedDay = AppModel.autoAdvancedSelectedDay(
            from: selectedDay,
            previousCurrentDay: previousCurrentDay,
            now: now,
            calendar: calendar
        )

        #expect(advancedDay == nil)
    }

    @Test func ignoresChecksBeforeTheDayActuallyChanges() {
        let calendar = makeCalendar()
        let previousCurrentDay = makeDate(year: 2026, month: 3, day: 30, hour: 0, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 3, day: 30, hour: 12, minute: 0, calendar: calendar)
        let now = makeDate(year: 2026, month: 3, day: 30, hour: 23, minute: 59, calendar: calendar)

        let advancedDay = AppModel.autoAdvancedSelectedDay(
            from: selectedDay,
            previousCurrentDay: previousCurrentDay,
            now: now,
            calendar: calendar
        )

        #expect(advancedDay == nil)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
