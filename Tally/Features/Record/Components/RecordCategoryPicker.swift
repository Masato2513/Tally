//
//  RecordCategoryPicker.swift
//  Tally
//

import SwiftUI

struct RecordCategoryPicker: View {
    let categories: [LedgerCategory]
    let subcategories: [LedgerSubcategory]
    let historicalCategory: LedgerCategory?
    let historicalSubcategory: LedgerSubcategory?
    @Binding var selectedCategoryID: UUID?
    @Binding var selectedSubcategoryID: UUID?

    private let categoryColumns = [
        GridItem(.adaptive(minimum: 72), spacing: 12)
    ]

    var body: some View {
        if categories.isEmpty && displayedHistoricalCategory == nil {
            ContentUnavailableView(
                "暂无可用分类",
                systemImage: "square.grid.2x2",
                description: Text("可以稍后在设置中启用或添加分类。")
            )
        } else {
            LazyVGrid(columns: categoryColumns, spacing: 12) {
                if let displayedHistoricalCategory {
                    historicalCategoryLabel(displayedHistoricalCategory)
                }

                ForEach(categories) { category in
                    categoryButton(category)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var displayedHistoricalCategory: LedgerCategory? {
        guard let historicalCategory,
              historicalCategory.isSoftDeleted,
              selectedCategoryID == historicalCategory.id
        else {
            return nil
        }
        return historicalCategory
    }

    private func historicalCategoryLabel(_ category: LedgerCategory) -> some View {
        categoryLabel(
            category,
            title: historicalDisplayTitle(for: category),
            isSelected: true
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(historicalDisplayTitle(for: category))
        .accessibilityValue("当前账单原分类，已删除")
    }

    @ViewBuilder
    private func categoryButton(_ category: LedgerCategory) -> some View {
        let isCategorySelected = selectedCategoryID == category.id
        let categorySubcategories = subcategories.filter { $0.categoryID == category.id }

        if categorySubcategories.isEmpty {
            Button {
                select(categoryID: category.id, subcategoryID: nil)
            } label: {
                categoryLabel(
                    category,
                    title: displayTitle(for: category),
                    isSelected: isCategorySelected
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(category.name)
            .accessibilityValue(selectionAccessibilityValue(for: category))
            .accessibilityHint("选择此分类")
            .accessibilityAddTraits(isCategorySelected ? .isSelected : [])
        } else {
            Menu {
                ForEach(
                    RecordCategorySelectionService.options(
                        for: category,
                        subcategories: categorySubcategories
                    )
                ) { option in
                    Button {
                        select(
                            categoryID: option.categoryID,
                            subcategoryID: option.subcategoryID
                        )
                    } label: {
                        if isSelected(option) {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                    .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
                }
            } label: {
                categoryLabel(
                    category,
                    title: displayTitle(for: category),
                    isSelected: isCategorySelected
                )
            }
            .menuOrder(.fixed)
            .buttonStyle(.plain)
            .accessibilityLabel(category.name)
            .accessibilityValue(selectionAccessibilityValue(for: category))
            .accessibilityHint("显示分类和子分类选项")
            .accessibilityAddTraits(isCategorySelected ? .isSelected : [])
        }
    }

    private func categoryLabel(
        _ category: LedgerCategory,
        title: String,
        isSelected: Bool
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: category.symbolName)
                .font(.title2)
                .frame(height: 28)
                .foregroundStyle(LedgerCategoryColor.resolve(for: category).color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        }
        .contentShape(.rect)
    }

    private func select(categoryID: UUID, subcategoryID: UUID?) {
        selectedCategoryID = categoryID
        selectedSubcategoryID = subcategoryID
    }

    private func isSelected(_ option: RecordCategoryOption) -> Bool {
        selectedCategoryID == option.categoryID
            && selectedSubcategoryID == option.subcategoryID
    }

    private func displayTitle(for category: LedgerCategory) -> String {
        guard selectedCategoryID == category.id,
              let selectedSubcategoryID
        else {
            return category.name
        }
        let subcategory = subcategories.first { $0.id == selectedSubcategoryID }
            ?? historicalSubcategory.flatMap {
                $0.id == selectedSubcategoryID && $0.categoryID == category.id ? $0 : nil
            }
        guard let subcategory else { return category.name }
        return "\(category.name) · \(subcategory.name)"
    }

    private func historicalDisplayTitle(for category: LedgerCategory) -> String {
        guard let historicalSubcategory,
              selectedSubcategoryID == historicalSubcategory.id,
              historicalSubcategory.categoryID == category.id
        else {
            return category.name
        }
        return "\(category.name) · \(historicalSubcategory.name)"
    }

    private func selectionAccessibilityValue(for category: LedgerCategory) -> String {
        guard selectedCategoryID == category.id else { return "未选择" }
        return "已选择，\(displayTitle(for: category))"
    }
}
