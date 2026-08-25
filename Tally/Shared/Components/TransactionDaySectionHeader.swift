//
//  TransactionDaySectionHeader.swift
//  Tally
//

import SwiftUI

struct TransactionDaySectionHeader: View {
    let date: Date
    let totals: LedgerTransactionTotals

    private let calendar: Calendar
    private let includesYear: Bool

    init(
        date: Date,
        transactions: [CurrentLedgerTransaction],
        calendar: Calendar = .autoupdatingCurrent,
        includesYear: Bool = false
    ) {
        self.date = date
        totals = StatisticsService.totals(for: transactions)
        self.calendar = calendar
        self.includesYear = includesYear
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(
                TransactionDayTitle.text(
                    for: date,
                    calendar: calendar,
                    includesYear: includesYear
                )
            )
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if totals.expenseInCents > 0 {
                    Text(
                        "支出 \(MoneyAmount.formatted(cents: totals.expenseInCents))"
                    )
                }

                if totals.incomeInCents > 0 {
                    Text(
                        "收入 \(MoneyAmount.formatted(cents: totals.incomeInCents))"
                    )
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .frame(maxWidth: .infinity)
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}
