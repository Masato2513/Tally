//
//  TransactionDaySectionHeader.swift
//  Tally
//

import SwiftUI

struct TransactionDaySectionHeader: View {
    let date: Date
    let expenseInCents: Int64

    private let calendar: Calendar

    init(
        date: Date,
        expenseInCents: Int64,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.date = date
        self.expenseInCents = expenseInCents
        self.calendar = calendar
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(TransactionDayTitle.text(for: date, calendar: calendar))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("支出 \(MoneyAmount.formatted(cents: expenseInCents))")
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .frame(maxWidth: .infinity)
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}
