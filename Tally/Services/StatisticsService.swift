//
//  StatisticsService.swift
//  Tally
//

import Foundation

struct MonthlyLedgerSummary: Equatable {
    let expenseInCents: Int64
    let incomeInCents: Int64

    var balanceInCents: Int64 {
        incomeInCents - expenseInCents
    }
}

enum StatisticsService {
    static func expenseTotal(for transactions: [LedgerTransaction]) -> Int64 {
        safeSum(
            transactions.lazy
                .filter { $0.type == .expense }
                .map(\.amountInCents)
        )
    }

    static func monthlySummary(
        for transactions: [LedgerTransaction],
        containing date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> MonthlyLedgerSummary {
        guard let interval = CalendarIntervals.month(containing: date, calendar: calendar) else {
            return MonthlyLedgerSummary(expenseInCents: 0, incomeInCents: 0)
        }

        let monthlyTransactions = transactions.filter { interval.contains($0.date) }
        let expense = expenseTotal(for: monthlyTransactions)
        let income = safeSum(
            monthlyTransactions.lazy
                .filter { $0.type == .income }
                .map(\.amountInCents)
        )

        return MonthlyLedgerSummary(expenseInCents: expense, incomeInCents: income)
    }

    static func transactionsWithinLastDays(
        _ dayCount: Int,
        from transactions: [LedgerTransaction],
        relativeTo date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [LedgerTransaction] {
        guard dayCount > 0 else { return [] }

        let startOfToday = calendar.startOfDay(for: date)
        guard
            let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: startOfToday),
            let endDate = calendar.date(byAdding: .day, value: 1, to: startOfToday)
        else {
            return []
        }

        return transactions
            .filter { $0.date >= startDate && $0.date < endDate }
            .sorted { $0.date > $1.date }
    }
}

private extension StatisticsService {
    static func safeSum<S: Sequence>(_ values: S) -> Int64 where S.Element == Int64 {
        values.reduce(into: 0) { result, value in
            let (sum, overflow) = result.addingReportingOverflow(value)
            result = overflow ? Int64.max : sum
        }
    }
}
