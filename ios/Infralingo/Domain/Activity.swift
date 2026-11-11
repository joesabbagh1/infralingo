import Foundation

/// A civil calendar day (a LocalDate), independent of any moment within it.
struct CalendarDay: Hashable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day containing `date` in `zone`.
    init(date: Date, zone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses "yyyy-MM-dd".
    init?(string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// The weekday as a single letter ("M", "T", "W", …), as the week dots show it.
    func narrowWeekday(zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = calendar.date(from: components) else { return "" }
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = DateFormatter().veryShortStandaloneWeekdaySymbols ?? []
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func - (lhs: CalendarDay, rhs: CalendarDay) -> Int {
        let utc = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        func noon(_ d: CalendarDay) -> Date {
            var components = DateComponents()
            components.year = d.year
            components.month = d.month
            components.day = d.day
            components.hour = 12
            return calendar.date(from: components)!
        }
        return Int(noon(lhs).timeIntervalSince(noon(rhs)) / 86_400)
    }

    func adding(days: Int) -> CalendarDay {
        CalendarDay(date: dateAtNoon(adding: Double(days) * 86_400), zone: TimeZone(identifier: "UTC")!)
    }

    private func dateAtNoon(adding seconds: Double) -> Date {
        let utc = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        let noon = calendar.date(from: components)!
        return noon.addingTimeInterval(seconds)
    }
}

struct Day: Equatable {
    var date: CalendarDay
    var xp: Int
    var answers: Int
}

/// Streak and daily totals come straight from the answer log, so they cannot drift from it.
enum Activity {
    static func days(reviews: [ReviewState], zone: TimeZone) -> [CalendarDay: Day] {
        Dictionary(grouping: reviews, by: { CalendarDay(date: Date(millis: $0.at), zone: zone) })
            .mapValues { onDay in
                Day(date: CalendarDay(date: Date(millis: onDay[0].at), zone: zone), xp: onDay.reduce(0) { $0 + $1.xp }, answers: onDay.count)
            }
    }

    static func streak(practiced: Set<CalendarDay>, today: CalendarDay) -> Int {
        // A day that has not been practiced yet does not break the streak until it ends.
        var cursor = practiced.contains(today) ? today : today.adding(days: -1)
        var count = 0
        while practiced.contains(cursor) {
            count += 1
            cursor = cursor.adding(days: -1)
        }
        return count
    }
}

extension Date {
    init(millis: Int64) {
        self = Date(timeIntervalSince1970: millis.milliseconds)
    }
}
