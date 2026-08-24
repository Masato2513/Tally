//
//  BillsTransactionRow.swift
//  Tally
//

import SwiftUI

/// 账单行的不可变显示数据，避免在行的 body 更新期间访问模型或执行格式化。
struct BillsTransactionDisplay: Equatable {
    private struct CacheKey: Hashable {
        let transactionID: UUID
        let transactionUpdatedAt: Date
        let categoryUpdatedAt: Date?
        let subcategoryUpdatedAt: Date?
        let showsDate: Bool
    }

    private static var cache: [CacheKey: BillsTransactionDisplay] = [:]
    private static let cacheLimit = 512

    let categoryTitle: String
    let symbolName: String
    let categoryColor: LedgerCategoryColor
    let dateText: String?
    let noteText: String?
    let amountText: String

    init(
        transaction: LedgerTransaction,
        category: LedgerCategory?,
        subcategory: LedgerSubcategory?,
        showsDate: Bool
    ) {
        let names = [category?.name, subcategory?.name].compactMap { $0 }
        categoryTitle = names.isEmpty ? "未分类" : names.joined(separator: " · ")
        symbolName = category?.symbolName ?? "questionmark.circle"
        categoryColor = LedgerCategoryColor.resolve(for: category)
        dateText = showsDate ? transaction.date.formatted(Self.dateTimeStyle) : nil
        noteText = transaction.note.isEmpty ? nil : transaction.note

        let signedAmount = transaction.type == .expense
            ? -transaction.amountInCents
            : transaction.amountInCents
        amountText = MoneyAmount.formatted(cents: signedAmount)
    }

    private static let dateTimeStyle = Date.FormatStyle()
        .month(.wide)
        .day()
        .hour(.twoDigits(amPM: .abbreviated))
        .minute(.twoDigits)
        .locale(Locale(identifier: "zh_CN"))

    static func cached(
        transaction: LedgerTransaction,
        category: LedgerCategory?,
        subcategory: LedgerSubcategory?,
        showsDate: Bool
    ) -> BillsTransactionDisplay {
        let key = CacheKey(
            transactionID: transaction.id,
            transactionUpdatedAt: transaction.updatedAt,
            categoryUpdatedAt: category?.updatedAt,
            subcategoryUpdatedAt: subcategory?.updatedAt,
            showsDate: showsDate
        )
        if let cachedDisplay = cache[key] {
            return cachedDisplay
        }

        if cache.count >= cacheLimit {
            cache.removeAll(keepingCapacity: true)
        }
        let display = BillsTransactionDisplay(
            transaction: transaction,
            category: category,
            subcategory: subcategory,
            showsDate: showsDate
        )
        cache[key] = display
        return display
    }
}

struct BillsTransactionRow: View, Equatable {
    let categoryTitle: String
    let symbolName: String
    let categoryColor: LedgerCategoryColor
    let dateText: String?
    let noteText: String?
    let amountText: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(categoryTitle)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: symbolName)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(categoryColor.color)
                }
                .font(.body)
                .lineLimit(1)

                if let dateText {
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let noteText {
                    Text(noteText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Text(amountText)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点编辑这笔账单")
    }
}
