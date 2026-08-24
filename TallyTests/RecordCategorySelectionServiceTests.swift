//
//  RecordCategorySelectionServiceTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class RecordCategorySelectionServiceTests: XCTestCase {
    func testDefaultExpenseCategoryUsesVisibleSystemFoodCategory() {
        let shopping = LedgerCategory(
            systemKey: "expense.shopping",
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 0,
            isSystem: true
        )
        let food = LedgerCategory(
            systemKey: "expense.food",
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 1,
            isSystem: true
        )

        XCTAssertEqual(
            RecordCategorySelectionService.defaultExpenseCategoryID(
                in: [shopping, food]
            ),
            food.id
        )
    }

    func testHiddenFoodCategoryIsNotSelectedByDefault() {
        let food = LedgerCategory(
            systemKey: "expense.food",
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true,
            isHidden: true
        )

        XCTAssertNil(
            RecordCategorySelectionService.defaultExpenseCategoryID(in: [food])
        )
    }

    func testSoftDeletedFoodCategoryIsNotSelectedByDefault() {
        let food = LedgerCategory(
            systemKey: "expense.food",
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true,
            isSoftDeleted: true
        )

        XCTAssertNil(
            RecordCategorySelectionService.defaultExpenseCategoryID(in: [food])
        )
    }

    func testOptionsStartWithPrimaryAndThenUseSubcategoryOrder() {
        let category = LedgerCategory(
            name: "医疗",
            type: .expense,
            symbolName: "cross.case",
            sortOrder: 0,
            isSystem: true
        )
        let otherCategoryID = UUID()
        let treatment = LedgerSubcategory(
            name: "治疗",
            categoryID: category.id,
            sortOrder: 1,
            isSystem: true
        )
        let medicine = LedgerSubcategory(
            name: "药品",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: true
        )
        let unrelated = LedgerSubcategory(
            name: "其他",
            categoryID: otherCategoryID,
            sortOrder: 0,
            isSystem: true
        )

        let options = RecordCategorySelectionService.options(
            for: category,
            subcategories: [treatment, unrelated, medicine]
        )

        XCTAssertEqual(options.map(\.title), ["医疗", "医疗 · 药品", "医疗 · 治疗"])
        XCTAssertNil(options[0].subcategoryID)
        XCTAssertEqual(options[1].subcategoryID, medicine.id)
        XCTAssertEqual(options[2].subcategoryID, treatment.id)
    }

    func testOptionsExcludeSoftDeletedSubcategories() {
        let category = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            sortOrder: 0,
            isSystem: false
        )
        let active = LedgerSubcategory(
            name: "用品",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: false
        )
        let deleted = LedgerSubcategory(
            name: "医疗",
            categoryID: category.id,
            sortOrder: 1,
            isSystem: false,
            isSoftDeleted: true
        )

        let options = RecordCategorySelectionService.options(
            for: category,
            subcategories: [active, deleted]
        )

        XCTAssertEqual(options.map(\.title), ["宠物", "宠物 · 用品"])
    }

    func testCategoryWithoutSubcategoriesOnlyProvidesPrimaryOption() {
        let category = LedgerCategory(
            name: "其他收益",
            type: .income,
            symbolName: "plus.circle",
            sortOrder: 0,
            isSystem: true
        )

        let options = RecordCategorySelectionService.options(
            for: category,
            subcategories: []
        )

        XCTAssertEqual(
            options,
            [
                RecordCategoryOption(
                    categoryID: category.id,
                    subcategoryID: nil,
                    title: "其他收益"
                )
            ]
        )
    }
}
