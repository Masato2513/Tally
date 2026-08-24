//
//  TransactionQueryView.swift
//  Tally
//

import SwiftData
import SwiftUI

/// 只观察指定日期范围内的账单，避免各页面长期持有全部历史记录。
struct TransactionQueryView<Content: View>: View {
    @Query private var transactions: [LedgerTransaction]

    private let content: ([LedgerTransaction]) -> Content

    init(
        interval: DateInterval,
        @ViewBuilder content: @escaping ([LedgerTransaction]) -> Content
    ) {
        let startDate = interval.start
        let endDate = interval.end
        let predicate = #Predicate<LedgerTransaction> { transaction in
            transaction.date >= startDate && transaction.date < endDate
        }
        _transactions = Query(
            filter: predicate,
            sort: [SortDescriptor(\LedgerTransaction.date, order: .reverse)]
        )
        self.content = content
    }

    var body: some View {
        content(transactions)
    }
}
