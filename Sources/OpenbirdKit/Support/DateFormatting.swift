import Foundation

public enum OpenbirdDateFormatting {
    public static func dayString(for date: Date) -> String {
        dayString(for: date, timeZone: .autoupdatingCurrent)
    }

    public static func date(fromDayString value: String) -> Date? {
        date(fromDayString: value, timeZone: .autoupdatingCurrent)
    }

    public static func timeString(for date: Date) -> String {
        timeString(for: date, timeZone: .autoupdatingCurrent)
    }

    public static func weekdayString(for date: Date) -> String {
        weekdayString(for: date, timeZone: .autoupdatingCurrent)
    }

    static func dayString(for date: Date, timeZone: TimeZone) -> String {
        formatter(locale: Locale(identifier: "en_US_POSIX"), timeZone: timeZone) { formatter in
            formatter.dateFormat = "yyyy-MM-dd"
        }.string(from: date)
    }

    static func date(fromDayString value: String, timeZone: TimeZone) -> Date? {
        formatter(locale: Locale(identifier: "en_US_POSIX"), timeZone: timeZone) { formatter in
            formatter.dateFormat = "yyyy-MM-dd"
        }.date(from: value)
    }

    static func timeString(for date: Date, timeZone: TimeZone) -> String {
        formatter(timeZone: timeZone) { formatter in
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        }.string(from: date)
    }

    static func weekdayString(for date: Date, timeZone: TimeZone) -> String {
        formatter(timeZone: timeZone) { formatter in
            formatter.dateFormat = "EEEE"
        }.string(from: date)
    }

    private static func formatter(
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        configure: (DateFormatter) -> Void
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = locale
        formatter.timeZone = timeZone
        configure(formatter)
        return formatter
    }
}
