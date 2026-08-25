//
//  CalendarReportService.swift
//  Tally
//

import Foundation

struct CalendarDaySummary: Identifiable, Equatable {
    let date: Date
    let amountInCents: Int64

    var id: Date { date }
}

struct CalendarMonthSnapshot: Equatable {
    let daySummaries: [CalendarDaySummary]
    let maximumDailyAmountInCents: Int64
    let monthlyAmountInCents: Int64
}

enum CalendarReportService {
    static func monthSnapshot(
        for transactions: [CurrentLedgerTransaction],
        inMonthContaining date: Date,
        transactionType: LedgerTransactionType = .expense,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CalendarMonthSnapshot {
        let summaries = daySummaries(
            for: transactions,
            inMonthContaining: date,
            transactionType: transactionType,
            calendar: calendar
        )
        return CalendarMonthSnapshot(
            daySummaries: summaries,
            maximumDailyAmountInCents: summaries.map(\.amountInCents).max() ?? 0,
            monthlyAmountInCents: MoneyArithmetic.sum(summaries.map(\.amountInCents))
        )
    }

    static func daySummaries(
        for transactions: [CurrentLedgerTransaction],
        inMonthContaining date: Date,
        transactionType: LedgerTransactionType = .expense,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [CalendarDaySummary] {
        guard let monthInterval = CalendarIntervals.month(containing: date, calendar: calendar) else {
            return []
        }

        let monthlyTransactions = transactions.filter {
            $0.type == transactionType
                && $0.date >= monthInterval.start
                && $0.date < monthInterval.end
        }
        let amountsByDay = Dictionary(grouping: monthlyTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        .mapValues { MoneyArithmetic.sum($0.map(\.amountInCents)) }

        var summaries: [CalendarDaySummary] = []
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            let day = calendar.startOfDay(for: currentDate)
            summaries.append(
                CalendarDaySummary(date: day, amountInCents: amountsByDay[day] ?? 0)
            )
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        return summaries
    }

    static func transactions(
        onDayContaining date: Date,
        from transactions: [CurrentLedgerTransaction],
        transactionType: LedgerTransactionType = .expense,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [CurrentLedgerTransaction] {
        guard let interval = CalendarIntervals.day(containing: date, calendar: calendar) else {
            return []
        }
        return transactions
            .filter {
                $0.type == transactionType
                    && $0.date >= interval.start
                    && $0.date < interval.end
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func leadingBlankCount(
        forMonthContaining date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        guard let monthStart = CalendarIntervals.month(containing: date, calendar: calendar)?.start else {
            return 0
        }
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    static func orderedVeryShortWeekdaySymbols(
        calendar: Calendar = .autoupdatingCurrent
    ) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let startIndex = max(0, min(6, calendar.firstWeekday - 1))
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    static func relativeIntensity(amountInCents: Int64, maximumInCents: Int64) -> Double {
        guard amountInCents > 0, maximumInCents > 0 else { return 0 }
        return min(1, Double(amountInCents) / Double(maximumInCents))
    }

    static func recordDate(
        on day: Date,
        relativeTo currentDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second], from: currentDate)
        var dayComponents = calendar.dateComponents([.era, .year, .month, .day], from: day)
        dayComponents.hour = time.hour
        dayComponents.minute = time.minute
        dayComponents.second = time.second
        return calendar.date(from: dayComponents) ?? calendar.startOfDay(for: day)
    }
}
