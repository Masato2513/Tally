//
//  LedgerTransactionPersistenceTests.swift
//  TallyTests
//

import SwiftData
import XCTest
@testable import Tally

@MainActor
final class LedgerTransactionPersistenceTests: XCTestCase {
    func testPersistsAnExactExpenseWithOptionalSubcategory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try DefaultCategorySeeder.seedIfNeeded(in: context)

        let categories = try context.fetch(FetchDescriptor<LedgerCategory>())
        let subcategories = try context.fetch(FetchDescriptor<LedgerSubcategory>())
        let foodCategory = try XCTUnwrap(categories.first { $0.systemKey == "expense.food" })
        let mealSubcategory = try XCTUnwrap(
            subcategories.first { $0.systemKey == "expense.food.meals" }
        )
        let transactionDate = Date(timeIntervalSince1970: 1_787_299_200)

        context.insert(
            LedgerTransaction(
                type: .expense,
                amountInCents: 2_835,
                date: transactionDate,
                note: "午饭",
                categoryID: foodCategory.id,
                subcategoryID: mealSubcategory.id
            )
        )
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<LedgerTransaction>())
        let transaction = try XCTUnwrap(transactions.first)

        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transaction.type, .expense)
        XCTAssertEqual(transaction.amountInCents, 2_835)
        XCTAssertEqual(transaction.date, transactionDate)
        XCTAssertEqual(transaction.note, "午饭")
        XCTAssertEqual(transaction.categoryID, foodCategory.id)
        XCTAssertEqual(transaction.subcategoryID, mealSubcategory.id)
    }

    func testPersistsAnIncomeWithoutSubcategory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let categoryID = UUID()

        context.insert(
            LedgerTransaction(
                type: .income,
                amountInCents: 1_200_000,
                date: .now,
                categoryID: categoryID
            )
        )
        try context.save()

        let transaction = try XCTUnwrap(
            try context.fetch(FetchDescriptor<LedgerTransaction>()).first
        )

        XCTAssertEqual(transaction.type, .income)
        XCTAssertEqual(transaction.amountInCents, 1_200_000)
        XCTAssertEqual(transaction.categoryID, categoryID)
        XCTAssertNil(transaction.subcategoryID)
    }

    func testPersistsTransactionEdits() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let originalCategoryID = UUID()
        let updatedCategoryID = UUID()
        let updatedDate = Date(timeIntervalSince1970: 1_787_385_600)
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 800,
            date: .now,
            note: "原备注",
            categoryID: originalCategoryID
        )
        context.insert(transaction)
        try context.save()

        transaction.type = .income
        transaction.amountInCents = 12_345
        transaction.date = updatedDate
        transaction.note = "修改后"
        transaction.categoryID = updatedCategoryID
        transaction.updatedAt = updatedDate
        try context.save()

        let saved = try XCTUnwrap(
            try context.fetch(FetchDescriptor<LedgerTransaction>()).first
        )
        XCTAssertEqual(saved.type, .income)
        XCTAssertEqual(saved.amountInCents, 12_345)
        XCTAssertEqual(saved.date, updatedDate)
        XCTAssertEqual(saved.note, "修改后")
        XCTAssertEqual(saved.categoryID, updatedCategoryID)
        XCTAssertEqual(saved.updatedAt, updatedDate)
    }

    func testPersistsTransactionDeletion() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 2_800,
            date: .now,
            categoryID: UUID()
        )
        context.insert(transaction)
        try context.save()

        context.delete(transaction)
        try context.save()

        let savedTransactions = try context.fetch(FetchDescriptor<LedgerTransaction>())
        XCTAssertTrue(savedTransactions.isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            LedgerTransaction.self,
            LedgerCategory.self,
            LedgerSubcategory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
