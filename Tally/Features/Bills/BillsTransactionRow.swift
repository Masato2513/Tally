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
        let showsYear: Bool
    }

    private static var cache: [CacheKey: BillsTransactionDisplay] = [:]
    private static let cacheLimit = 512

    let categoryTitle: String
    let symbolName: String
    let categoryColor: LedgerCategoryColor
    let secondaryText: String?
    let amountText: String
    let transactionType: LedgerTransactionType

    init(
        transaction: CurrentLedgerTransaction,
        category: CurrentLedgerCategory?,
        subcategory: CurrentLedgerSubcategory?,
        showsDate: Bool,
        showsYear: Bool = false
    ) {
        let names = [category?.name, subcategory?.name].compactMap { $0 }
        categoryTitle = names.isEmpty ? "未分类" : names.joined(separator: " · ")
        symbolName = category?.symbolName ?? "questionmark.circle"
        categoryColor = LedgerCategoryColor.resolve(for: category)
        let dateText: String?
        if showsDate {
            dateText = transaction.date.formatted(
                showsYear ? Self.dateStyleWithYear : Self.dateStyle
            )
        } else {
            dateText = nil
        }
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

        amountText = MoneyAmount.formatted(cents: transaction.amountInCents)
        transactionType = transaction.type
    }

    private static let dateStyle = Date.FormatStyle()
        .month(.wide)
        .day()
        .locale(Locale(identifier: "zh_CN"))

    private static let dateStyleWithYear = Date.FormatStyle()
        .year()
        .month(.wide)
        .day()
        .locale(Locale(identifier: "zh_CN"))

    static func cached(
        transaction: CurrentLedgerTransaction,
        category: CurrentLedgerCategory?,
        subcategory: CurrentLedgerSubcategory?,
        showsDate: Bool,
        showsYear: Bool = false
    ) -> BillsTransactionDisplay {
        let key = CacheKey(
            transactionID: transaction.id,
            transactionUpdatedAt: transaction.updatedAt,
            categoryUpdatedAt: category?.updatedAt,
            subcategoryUpdatedAt: subcategory?.updatedAt,
            showsDate: showsDate,
            showsYear: showsYear
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
            showsDate: showsDate,
            showsYear: showsYear
        )
        cache[key] = display
        return display
    }
}

struct BillsTransactionRow: View, Equatable {
    let display: BillsTransactionDisplay

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: display.symbolName)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(display.categoryColor.color)
                .font(.body)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(display.categoryTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let secondaryText = display.secondaryText {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            Text(display.amountText)
                .font(.body.weight(.medium))
                .foregroundStyle(amountColor)
                .monospacedDigit()
                .accessibilityLabel(
                    "\(display.transactionType.title)，\(display.amountText)"
                )
        }
        .frame(minHeight: 44)
        .padding(.vertical, 3)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点编辑这笔账单")
    }

    private var amountColor: Color {
        LedgerTransactionStyle.amountColor(for: display.transactionType)
    }
}
