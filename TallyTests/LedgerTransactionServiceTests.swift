//
//  LedgerTransactionServiceTests.swift
//  TallyTests
//

import SwiftData
import XCTest
@testable import Tally

@MainActor
final class LedgerTransactionServiceTests: XCTestCase {
    func testSavesValidatedTransactionAndNormalizesNote() throws {
        let (_, context) = try makeContext()
        let category = CurrentLedgerCategory(
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 0,
            isSystem: true
        )
        let subcategory = CurrentLedgerSubcategory(
            name: "日常",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: true
        )
        context.insert(category)
        context.insert(subcategory)
        try context.save()

        let transaction = try LedgerTransactionService.save(
            LedgerTransactionInput(
                type: .expense,
                amountInCents: 5_538,
                date: .now,
                note: "  朴朴  \n",
                categoryID: category.id,
                subcategoryID: subcategory.id
            ),
            editing: nil,
            categories: [category],
            subcategories: [subcategory],
            in: context
        )

        XCTAssertEqual(transaction.note, "朴朴")
        XCTAssertEqual(try context.fetch(FetchDescriptor<CurrentLedgerTransaction>()).count, 1)
    }

    func testRejectsInvalidAmountCategoryAndSubcategory() throws {
        let (_, context) = try makeContext()
        let category = CurrentLedgerCategory(
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 0,
            isSystem: true
        )
        let otherCategory = CurrentLedgerCategory(
            name: "交通",
            type: .expense,
            symbolName: "car",
            sortOrder: 1,
            isSystem: true
        )
        let mismatchedSubcategory = CurrentLedgerSubcategory(
            name: "公交",
            categoryID: otherCategory.id,
            sortOrder: 0,
            isSystem: true
        )

        XCTAssertThrowsError(
            try LedgerTransactionService.validate(
                input(amount: 0, categoryID: category.id),
                editing: nil,
                categories: [category],
                subcategories: []
            )
        ) { error in
            XCTAssertEqual(error as? LedgerTransactionValidationError, .invalidAmount)
        }
        XCTAssertThrowsError(
            try LedgerTransactionService.validate(
                input(amount: 100, categoryID: UUID()),
                editing: nil,
                categories: [category],
                subcategories: []
            )
        ) { error in
            XCTAssertEqual(error as? LedgerTransactionValidationError, .invalidCategory)
        }
        XCTAssertThrowsError(
            try LedgerTransactionService.validate(
                input(
                    amount: 100,
                    categoryID: category.id,
                    subcategoryID: mismatchedSubcategory.id
                ),
                editing: nil,
                categories: [category, otherCategory],
                subcategories: [mismatchedSubcategory]
            )
        ) { error in
            XCTAssertEqual(error as? LedgerTransactionValidationError, .invalidSubcategory)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<CurrentLedgerTransaction>()).isEmpty)
    }

    func testEditingKeepsUnchangedSoftDeletedHistoricalSelection() throws {
        let (_, context) = try makeContext()
        let category = CurrentLedgerCategory(
            name: "旧分类",
            type: .expense,
            symbolName: "archivebox",
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        let subcategory = CurrentLedgerSubcategory(
            name: "旧子分类",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        let transaction = CurrentLedgerTransaction(
            type: .expense,
            amountInCents: 1_000,
            date: .now,
            categoryID: category.id,
            subcategoryID: subcategory.id
        )
        context.insert(category)
        context.insert(subcategory)
        context.insert(transaction)
        try context.save()

        try LedgerTransactionService.save(
            LedgerTransactionInput(
                type: .expense,
                amountInCents: 2_000,
                date: transaction.date,
                note: "只修改金额与备注",
                categoryID: category.id,
                subcategoryID: subcategory.id
            ),
            editing: transaction,
            categories: [category],
            subcategories: [subcategory],
            in: context
        )

        XCTAssertEqual(transaction.amountInCents, 2_000)
        XCTAssertEqual(transaction.categoryID, category.id)
        XCTAssertEqual(transaction.subcategoryID, subcategory.id)
    }

    func testRejectsAbnormallyLargeNote() throws {
        let category = CurrentLedgerCategory(
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 0,
            isSystem: true
        )
        let oversizedNote = String(
            repeating: "a",
            count: LedgerTransactionService.maximumNoteSizeInBytes + 1
        )

        XCTAssertThrowsError(
            try LedgerTransactionService.validate(
                LedgerTransactionInput(
                    type: .expense,
                    amountInCents: 100,
                    date: .now,
                    note: oversizedNote,
                    categoryID: category.id,
                    subcategoryID: nil
                ),
                editing: nil,
                categories: [category],
                subcategories: []
            )
        ) { error in
            XCTAssertEqual(error as? LedgerTransactionValidationError, .noteTooLarge)
        }
    }

    private func input(
        amount: Int64,
        categoryID: UUID,
        subcategoryID: UUID? = nil
    ) -> LedgerTransactionInput {
        LedgerTransactionInput(
            type: .expense,
            amountInCents: amount,
            date: .now,
            note: "",
            categoryID: categoryID,
            subcategoryID: subcategoryID
        )
    }

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = TallyModelContainerFactory.currentSchema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try TallyModelContainerFactory.make(configuration: configuration)
        return (container, ModelContext(container))
    }
}
