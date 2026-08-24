//
//  CalendarIntervals.swift
//  Tally
//

import Foundation

enum CalendarIntervals {
    static func month(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> DateInterval? {
        calendar.dateInterval(of: .month, for: date)
    }

    static func day(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> DateInterval? {
        calendar.dateInterval(of: .day, for: date)
    }

    static func monthAndRecentDays(
        _ dayCount: Int,
        containing date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval? {
        guard dayCount > 0, let monthInterval = month(containing: date, calendar: calendar) else {
            return nil
        }
        let startOfToday = calendar.startOfDay(for: date)
        guard
            let recentStart = calendar.date(
                byAdding: .day,
                value: -(dayCount - 1),
                to: startOfToday
            )
        else {
            return nil
        }
        return DateInterval(
            start: min(monthInterval.start, recentStart),
            end: monthInterval.end
        )
    }
}
