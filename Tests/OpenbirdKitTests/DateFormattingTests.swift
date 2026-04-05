import Foundation
import Testing
@testable import OpenbirdKit

@Suite(.serialized)
struct DateFormattingTests {
    @Test func dayAndWeekdayFormattingRespectTheRequestedTimezone() throws {
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        let date = try #require(calendar.date(from: DateComponents(
            timeZone: seoul,
            year: 2026,
            month: 4,
            day: 5,
            hour: 0,
            minute: 30
        )))

        #expect(OpenbirdDateFormatting.dayString(for: date, timeZone: losAngeles) == "2026-04-04")
        #expect(OpenbirdDateFormatting.weekdayString(for: date, timeZone: losAngeles) == "Saturday")
        #expect(OpenbirdDateFormatting.dayString(for: date, timeZone: seoul) == "2026-04-05")
        #expect(OpenbirdDateFormatting.weekdayString(for: date, timeZone: seoul) == "Sunday")
    }

    @Test func dayStringParsingRoundTripsWithinTheSameTimezone() throws {
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        let parsedDate = try #require(OpenbirdDateFormatting.date(fromDayString: "2026-04-05", timeZone: seoul))

        #expect(OpenbirdDateFormatting.dayString(for: parsedDate, timeZone: seoul) == "2026-04-05")
    }
}
