//
//  CategoryManagementServiceTests.swift
//  TallyTests
//

import SwiftData
import XCTest
@testable import Tally

@MainActor
final class CategoryManagementServiceTests: XCTestCase {
    func testCreatesTrimmedUserCategoryAfterExistingOrder() throws {
        let (container, context) = try makeContext()
        _ = container
        let existing = LedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 4,
            isSystem: true
        )
        context.insert(existing)
        try context.save()

        let created = try CategoryManagementService.createCategory(
            name: "  宠物  ",
            type: .expense,
            symbolName: "pawprint",
            among: [existing],
            in: context
        )

        XCTAssertEqual(created.name, "宠物")
        XCTAssertEqual(created.sortOrder, 5)
        XCTAssertFalse(created.isSystem)
        XCTAssertNil(created.systemKey)
        XCTAssertEqual(created.colorRawValue, LedgerCategoryColor.blue.rawValue)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LedgerCategory>()).count, 2)
    }

    func testRejectsDuplicateNamesWithinTheSameLevelOnly() throws {
        let (container, context) = try makeContext()
        _ = container
        let expense = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            sortOrder: 0,
            isSystem: false
        )
        context.insert(expense)
        try context.save()

        XCTAssertThrowsError(
            try CategoryManagementService.createCategory(
                name: " 宠物 ",
                type: .expense,
                symbolName: "pawprint",
                among: [expense],
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? CategoryManagementError, .duplicateName)
        }

        XCTAssertNoThrow(
            try CategoryManagementService.createCategory(
                name: "宠物",
                type: .income,
                symbolName: "pawprint",
                among: [expense],
                in: context
            )
        )
    }

    func testSystemCategoryCannotBeEditedButUserCategoryCan() throws {
        let (container, context) = try makeContext()
        _ = container
        let system = LedgerCategory(
            systemKey: "expense.food",
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true
        )
        let user = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            sortOrder: 1,
            isSystem: false
        )
        context.insert(system)
        context.insert(user)
        try context.save()

        XCTAssertThrowsError(
            try CategoryManagementService.updateCategory(
                system,
                name: "吃饭",
                symbolName: "cup.and.saucer",
                among: [system, user],
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? CategoryManagementError, .cannotEditSystemCategory)
        }

        try CategoryManagementService.updateCategory(
            user,
            name: "萌宠",
            symbolName: "heart",
            color: .mint,
            among: [system, user],
            in: context
        )

        XCTAssertEqual(system.name, "餐饮")
        XCTAssertEqual(user.name, "萌宠")
        XCTAssertEqual(user.symbolName, "heart")
        XCTAssertEqual(LedgerCategoryColor.resolve(for: user), .mint)
    }

    func testCreatesEditsHidesAndOrdersUserSubcategories() throws {
        let (container, context) = try makeContext()
        _ = container
        let category = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            sortOrder: 0,
            isSystem: false
        )
        context.insert(category)
        try context.save()

        let supplies = try CategoryManagementService.createSubcategory(
            name: "用品",
            for: category,
            among: [],
            in: context
        )
        let medical = try CategoryManagementService.createSubcategory(
            name: "医疗",
            for: category,
            among: [supplies],
            in: context
        )
        try CategoryManagementService.updateSubcategory(
            supplies,
            name: "日常用品",
            among: [supplies, medical],
            in: context
        )
        try CategoryManagementService.setSubcategoryHidden(
            medical,
            hidden: true,
            in: context
        )
        try CategoryManagementService.applySubcategoryOrder(
            [medical, supplies],
            in: context
        )

        XCTAssertEqual(supplies.name, "日常用品")
        XCTAssertTrue(medical.isHidden)
        XCTAssertEqual(medical.sortOrder, 0)
        XCTAssertEqual(supplies.sortOrder, 1)
    }

    func testHidingAndReorderingCategoryPreservesHistoricalTransaction() throws {
        let (container, context) = try makeContext()
        _ = container
        let food = LedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true
        )
        let shopping = LedgerCategory(
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 1,
            isSystem: true
        )
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 2_800,
            date: .now,
            categoryID: food.id
        )
        context.insert(food)
        context.insert(shopping)
        context.insert(transaction)
        try context.save()

        try CategoryManagementService.setCategoryHidden(food, hidden: true, in: context)
        try CategoryManagementService.applyCategoryOrder([shopping, food], in: context)

        let persistedTransactions = try context.fetch(FetchDescriptor<LedgerTransaction>())
        XCTAssertTrue(food.isHidden)
        XCTAssertEqual(shopping.sortOrder, 0)
        XCTAssertEqual(food.sortOrder, 1)
        XCTAssertEqual(persistedTransactions.map(\.categoryID), [food.id])
    }

    func testSoftDeletingUserCategoryKeepsModelsAndHistoricalTransaction() throws {
        let (container, context) = try makeContext()
        _ = container
        let category = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .mint,
            sortOrder: 0,
            isSystem: false
        )
        let subcategory = LedgerSubcategory(
            name: "用品",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: false
        )
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 2_800,
            date: .now,
            categoryID: category.id,
            subcategoryID: subcategory.id
        )
        context.insert(category)
        context.insert(subcategory)
        context.insert(transaction)
        try context.save()

        try CategoryManagementService.softDeleteCategory(
            category,
            subcategories: [subcategory],
            in: context
        )

        let persistedCategories = try context.fetch(FetchDescriptor<LedgerCategory>())
        let persistedSubcategories = try context.fetch(FetchDescriptor<LedgerSubcategory>())
        let persistedTransactions = try context.fetch(FetchDescriptor<LedgerTransaction>())
        XCTAssertEqual(persistedCategories.count, 1)
        XCTAssertEqual(persistedSubcategories.count, 1)
        XCTAssertEqual(persistedTransactions.count, 1)
        XCTAssertTrue(category.isSoftDeleted)
        XCTAssertTrue(subcategory.isSoftDeleted)
        XCTAssertEqual(persistedTransactions.first?.categoryID, category.id)
        XCTAssertEqual(persistedTransactions.first?.subcategoryID, subcategory.id)
        let display = LedgerCategoryLookup(
            categories: persistedCategories,
            subcategories: persistedSubcategories
        ).display(for: transaction, showsDate: false)
        XCTAssertEqual(display.categoryTitle, "宠物 · 用品")
        XCTAssertEqual(display.symbolName, "pawprint")
        XCTAssertEqual(display.categoryColor, .mint)
        XCTAssertTrue(CategoryManagementService.categories(of: .expense, from: [category]).isEmpty)
        XCTAssertTrue(
            CategoryManagementService.subcategories(
                of: category.id,
                from: [subcategory]
            ).isEmpty
        )
    }

    func testSystemCategoryAndSubcategoryCannotBeSoftDeleted() throws {
        let (container, context) = try makeContext()
        _ = container
        let category = LedgerCategory(
            systemKey: "expense.food",
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true
        )
        let subcategory = LedgerSubcategory(
            systemKey: "expense.food.meals",
            name: "三餐",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: true
        )
        context.insert(category)
        context.insert(subcategory)
        try context.save()

        XCTAssertThrowsError(
            try CategoryManagementService.softDeleteCategory(
                category,
                subcategories: [subcategory],
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? CategoryManagementError, .cannotDeleteSystemCategory)
        }
        XCTAssertThrowsError(
            try CategoryManagementService.softDeleteSubcategory(
                subcategory,
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? CategoryManagementError, .cannotDeleteSystemCategory)
        }
        XCTAssertFalse(category.isSoftDeleted)
        XCTAssertFalse(subcategory.isSoftDeleted)
    }

    func testSoftDeletingUserSubcategoryKeepsHistoricalDisplayAndParent() throws {
        let (container, context) = try makeContext()
        _ = container
        let category = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .pink,
            sortOrder: 0,
            isSystem: false
        )
        let subcategory = LedgerSubcategory(
            name: "医疗",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: false
        )
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 1_200,
            date: .now,
            categoryID: category.id,
            subcategoryID: subcategory.id
        )
        context.insert(category)
        context.insert(subcategory)
        context.insert(transaction)
        try context.save()

        try CategoryManagementService.softDeleteSubcategory(
            subcategory,
            in: context
        )

        XCTAssertFalse(category.isSoftDeleted)
        XCTAssertTrue(subcategory.isSoftDeleted)
        XCTAssertEqual(transaction.subcategoryID, subcategory.id)
        let display = LedgerCategoryLookup(
            categories: [category],
            subcategories: [subcategory]
        ).display(for: transaction, showsDate: false)
        XCTAssertEqual(display.categoryTitle, "宠物 · 医疗")
    }

    func testRecreatingDeletedNamesUsesNewIndependentIDs() throws {
        let (container, context) = try makeContext()
        _ = container
        let deletedCategory = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .mint,
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        context.insert(deletedCategory)
        try context.save()

        let newCategory = try CategoryManagementService.createCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .mint,
            among: [deletedCategory],
            in: context
        )
        let deletedSubcategory = LedgerSubcategory(
            name: "用品",
            categoryID: newCategory.id,
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        context.insert(deletedSubcategory)
        try context.save()
        let newSubcategory = try CategoryManagementService.createSubcategory(
            name: "用品",
            for: newCategory,
            among: [deletedSubcategory],
            in: context
        )

        XCTAssertNotEqual(newCategory.id, deletedCategory.id)
        XCTAssertNotEqual(newSubcategory.id, deletedSubcategory.id)
        XCTAssertFalse(newCategory.isSoftDeleted)
        XCTAssertFalse(newSubcategory.isSoftDeleted)
    }

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([
            LedgerTransaction.self,
            LedgerCategory.self,
            LedgerSubcategory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, ModelContext(container))
    }
}
