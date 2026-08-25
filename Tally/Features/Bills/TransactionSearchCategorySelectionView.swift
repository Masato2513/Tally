//
//  TransactionSearchCategorySelectionView.swift
//  Tally
//

import SwiftUI

struct TransactionSearchCategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCategoryID: UUID?
    let categories: [CurrentLedgerCategory]

    var body: some View {
        List {
            Section {
                selectionRow(
                    title: "全部分类",
                    symbolName: nil,
                    color: nil,
                    categoryID: nil
                )
            }

            Section("支出") {
                ForEach(expenseCategories) { category in
                    categoryRow(category)
                }
            }

            Section("收入") {
                ForEach(incomeCategories) { category in
                    categoryRow(category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("分类")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var expenseCategories: [CurrentLedgerCategory] {
        categories.filter { $0.type == .expense }
    }

    private var incomeCategories: [CurrentLedgerCategory] {
        categories.filter { $0.type == .income }
    }

    private func categoryRow(_ category: CurrentLedgerCategory) -> some View {
        selectionRow(
            title: category.name,
            symbolName: category.symbolName,
            color: LedgerCategoryColor.resolve(for: category).color,
            categoryID: category.id
        )
    }

    private func selectionRow(
        title: String,
        symbolName: String?,
        color: Color?,
        categoryID: UUID?
    ) -> some View {
        Button {
            selectedCategoryID = categoryID
            dismiss()
        } label: {
            HStack(spacing: 12) {
                if let symbolName, let color {
                    Image(systemName: symbolName)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(color)
                        .frame(width: 20)
                }

                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                if selectedCategoryID == categoryID {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            selectedCategoryID == categoryID ? .isSelected : []
        )
    }
}
