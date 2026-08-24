//
//  BillsTransactionDisplayTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class BillsTransactionDisplayTests: XCTestCase {
    func testDateAndNoteShareOneSecondaryLineWithoutTime() throws {
        let date = try makeDate(year: 2026, month: 8, day: 22, hour: 19, minute: 3)
        let category = makeCategory()
        let subcategory = LedgerSubcategory(
            name: "日常",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: true
        )
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 5_538,
            date: date,
            note: "朴朴",
            categoryID: category.id,
            subcategoryID: subcategory.id
        )

        let display = BillsTransactionDisplay(
            transaction: transaction,
            category: category,
            subcategory: subcategory,
            showsDate: true
        )

        XCTAssertEqual(display.categoryTitle, "购物 · 日常")
        XCTAssertEqual(display.secondaryText, "8月22日 · 朴朴")
        XCTAssertFalse(display.secondaryText?.contains("19") ?? true)
        XCTAssertFalse(display.secondaryText?.contains(":") ?? true)
    }

    func testDateOnlyIsShownWhenTheListHasNoDateContext() throws {
        let category = makeCategory()
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 4_520,
            date: try makeDate(year: 2026, month: 8, day: 22, hour: 9, minute: 30),
            categoryID: category.id
        )

        let display = BillsTransactionDisplay(
            transaction: transaction,
            category: category,
            subcategory: nil,
            showsDate: true
        )

        XCTAssertEqual(display.secondaryText, "8月22日")
    }

    func testGroupedListsOnlyUseTheNoteAsSecondaryText() throws {
        let category = makeCategory()
        let transaction = LedgerTransaction(
            type: .expense,
            amountInCents: 2_400,
            date: try makeDate(year: 2026, month: 8, day: 22, hour: 9, minute: 30),
            note: "日用品",
            categoryID: category.id
        )

        let display = BillsTransactionDisplay(
            transaction: transaction,
            category: category,
            subcategory: nil,
            showsDate: false
        )

        XCTAssertEqual(display.secondaryText, "日用品")
    }

    private func makeCategory() -> LedgerCategory {
        LedgerCategory(
            systemKey: "expense.shopping",
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 0,
            isSystem: true
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }
}
