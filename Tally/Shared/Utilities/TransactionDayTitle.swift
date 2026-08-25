//
//  TransactionDayTitle.swift
//  Tally
//

import Foundation

enum TransactionDayTitle {
    static func text(
        for date: Date,
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        includesYear: Bool = false
    ) -> String {
        let dateText: String
        if includesYear {
            dateText = date.formatted(
                Date.FormatStyle()
                    .year()
                    .month(.wide)
                    .day()
                    .locale(Locale(identifier: "zh_CN"))
            )
        } else {
            dateText = date.formatted(
                Date.FormatStyle()
                    .month(.wide)
                    .day()
                    .locale(Locale(identifier: "zh_CN"))
            )
        }

        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return "\(dateText) 今天"
        }

        let startOfReferenceDate = calendar.startOfDay(for: referenceDate)
        if
            let yesterday = calendar.date(
                byAdding: .day,
                value: -1,
                to: startOfReferenceDate
            ),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "\(dateText) 昨天 \(weekdayText(for: date))"
        }

        return "\(dateText) \(weekdayText(for: date))"
    }

    private static func weekdayText(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}
