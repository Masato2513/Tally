//
//  RecordCategorySelectionService.swift
//  Tally
//

import Foundation

struct RecordCategoryOption: Identifiable, Equatable {
    let categoryID: UUID
    let subcategoryID: UUID?
    let title: String

    var id: String {
        "\(categoryID.uuidString):\(subcategoryID?.uuidString ?? "primary")"
    }
}

enum RecordCategorySelectionService {
    static func defaultExpenseCategoryID(
        in categories: [LedgerCategory]
    ) -> UUID? {
        categories
            .filter {
                $0.type == .expense
                    && !$0.isHidden
                    && !$0.isSoftDeleted
            }
            .min { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }?.id
    }

    static func options(
        for category: LedgerCategory,
        subcategories: [LedgerSubcategory]
    ) -> [RecordCategoryOption] {
        let primary = RecordCategoryOption(
            categoryID: category.id,
            subcategoryID: nil,
            title: category.name
        )
        let secondary = subcategories
            .filter { $0.categoryID == category.id && !$0.isSoftDeleted }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { subcategory in
                RecordCategoryOption(
                    categoryID: category.id,
                    subcategoryID: subcategory.id,
                    title: "\(category.name) · \(subcategory.name)"
                )
            }
        return [primary] + secondary
    }
}
