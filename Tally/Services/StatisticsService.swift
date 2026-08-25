//
//  StatisticsService.swift
//  Tally
//

import Foundation

struct MonthlyLedgerSummary: Equatable {
    let expenseInCents: Int64
    let incomeInCents: Int64

    var balanceInCents: Int64 {
        MoneyArithmetic.subtract(expenseInCents, from: incomeInCents)
    }
}

struct LedgerTransactionTotals: Equatable {
    let expenseInCents: Int64
    let incomeInCents: Int64
}

enum StatisticsService {
    static func expenseTotal(for transactions: [CurrentLedgerTransaction]) -> Int64 {
        total(for: .expense, in: transactions)
    }

    static func incomeTotal(for transactions: [CurrentLedgerTransaction]) -> Int64 {
        total(for: .income, in: transactions)
    }

    static func totals(for transactions: [CurrentLedgerTransaction]) -> LedgerTransactionTotals {
        LedgerTransactionTotals(
            expenseInCents: expenseTotal(for: transactions),
            incomeInCents: incomeTotal(for: transactions)
        )
    }

    private static func total(
        for type: LedgerTransactionType,
        in transactions: [CurrentLedgerTransaction]
    ) -> Int64 {
        MoneyArithmetic.sum(
            transactions.lazy
                .filter { $0.type == type }
                .map(\.amountInCents)
        )
    }

    static func monthlySummary(
        for transactions: [CurrentLedgerTransaction],
        containing date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> MonthlyLedgerSummary {
        guard let interval = CalendarIntervals.month(containing: date, calendar: calendar) else {
            return MonthlyLedgerSummary(expenseInCents: 0, incomeInCents: 0)
        }

        let monthlyTransactions = transactions.filter { interval.containsHalfOpen($0.date) }
        let totals = totals(for: monthlyTransactions)

        return MonthlyLedgerSummary(
            expenseInCents: totals.expenseInCents,
            incomeInCents: totals.incomeInCents
        )
    }

    static func transactionsWithinLastDays(
        _ dayCount: Int,
        from transactions: [CurrentLedgerTransaction],
        relativeTo date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [CurrentLedgerTransaction] {
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
