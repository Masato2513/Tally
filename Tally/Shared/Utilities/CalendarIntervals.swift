//
//  CalendarIntervals.swift
//  Tally
//

import Foundation

extension DateInterval {
    /// 日历统计统一使用左闭右开区间，避免下一个自然日/月的零点被重复计入。
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

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
