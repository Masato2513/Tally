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
    let secondaryText: String?
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
        let dateText = showsDate ? transaction.date.formatted(Self.dateStyle) : nil
        let noteText = transaction.note.isEmpty ? nil : transaction.note
        secondaryText = switch (dateText, noteText) {
        case let (.some(date), .some(note)):
            "\(date) · \(note)"
        case let (.some(date), .none):
            date
        case let (.none, .some(note)):
            note
        case (.none, .none):
            nil
        }

        let signedAmount = transaction.type == .expense
            ? -transaction.amountInCents
            : transaction.amountInCents
        amountText = MoneyAmount.formatted(cents: signedAmount)
    }

    private static let dateStyle = Date.FormatStyle()
        .month(.wide)
        .day()
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
    let secondaryText: String?
    let amountText: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(categoryColor.color)
                .font(.body)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(categoryTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let secondaryText {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            Text(amountText)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(minHeight: 44)
        .padding(.vertical, 3)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点编辑这笔账单")
    }
}
