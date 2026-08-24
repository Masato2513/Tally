//
//  LedgerCategoryLookup.swift
//  Tally
//

import Foundation

/// 单次页面更新共用的分类索引，避免为每一条账单重复构建字典。
struct LedgerCategoryLookup {
    private let categoriesByID: [UUID: LedgerCategory]
    private let subcategoriesByID: [UUID: LedgerSubcategory]

    init(
        categories: [LedgerCategory],
        subcategories: [LedgerSubcategory]
    ) {
        categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        subcategoriesByID = Dictionary(uniqueKeysWithValues: subcategories.map { ($0.id, $0) })
    }

    func display(
        for transaction: LedgerTransaction,
        showsDate: Bool
    ) -> BillsTransactionDisplay {
        let category = categoriesByID[transaction.categoryID]
        let subcategory = transaction.subcategoryID.flatMap { subcategoriesByID[$0] }
        return BillsTransactionDisplay.cached(
            transaction: transaction,
            category: category,
            subcategory: subcategory,
            showsDate: showsDate
        )
    }
}
