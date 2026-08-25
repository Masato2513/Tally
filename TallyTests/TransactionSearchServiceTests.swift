//
//  TransactionSearchServiceTests.swift
//  TallyTests
//

import SwiftData
import XCTest
@testable import Tally

@MainActor
final class TransactionSearchServiceTests: XCTestCase {
    func testKeywordSearchIncludesNotesAndHistoricalCategoryHierarchy() throws {
        let context = try makeContext()
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 25, calendar: calendar)
        let food = CurrentLedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        let shopping = CurrentLedgerCategory(
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 1,
            isSystem: true
        )
        let coffee = CurrentLedgerSubcategory(
            name: "咖啡",
            categoryID: shopping.id,
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        let categoryMatch = transaction(
            amount: 1_000,
            date: referenceDate,
            categoryID: food.id
        )
        let subcategoryMatch = transaction(
            amount: 2_000,
            date: referenceDate,
            categoryID: shopping.id,
            subcategoryID: coffee.id
        )
        let noteMatch = transaction(
            amount: 3_000,
            date: referenceDate,
            note: "周末早餐",
            categoryID: shopping.id
        )
        [food, shopping].forEach(context.insert)
        context.insert(coffee)
        [categoryMatch, subcategoryMatch, noteMatch].forEach(context.insert)
        try context.save()

        let categoryResult = try TransactionSearchService.search(
            keyword: "餐饮",
            filters: TransactionSearchFilters(),
            sortOrder: .time,
            limit: 100,
            in: context,
            relativeTo: referenceDate,
            calendar: calendar
        )
        let subcategoryResult = try TransactionSearchService.search(
            keyword: "咖啡",
            filters: TransactionSearchFilters(),
            sortOrder: .time,
            limit: 100,
            in: context,
            relativeTo: referenceDate,
            calendar: calendar
        )
        let noteResult = try TransactionSearchService.search(
            keyword: "早餐",
            filters: TransactionSearchFilters(),
            sortOrder: .time,
            limit: 100,
            in: context,
            relativeTo: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(categoryResult.transactions.map(\.id), [categoryMatch.id])
        XCTAssertEqual(subcategoryResult.transactions.map(\.id), [subcategoryMatch.id])
        XCTAssertEqual(noteResult.transactions.map(\.id), [noteMatch.id])
    }

    func testFiltersSortAndLimitAreAppliedBeforeResultsAreReturned() throws {
        let context = try makeContext()
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 25, calendar: calendar)
        let foodID = UUID()
        let otherID = UUID()
        let matchingTransactions = [
            transaction(
                amount: 2_000,
                date: try makeDate(year: 2026, month: 8, day: 2, calendar: calendar),
                categoryID: foodID
            ),
            transaction(
                amount: 4_000,
                date: try makeDate(year: 2026, month: 8, day: 3, calendar: calendar),
                categoryID: foodID
            ),
            transaction(
                amount: 3_000,
                date: try makeDate(year: 2026, month: 8, day: 4, calendar: calendar),
                categoryID: foodID
            )
        ]
        let excludedByCategory = transaction(
            amount: 9_000,
            date: referenceDate,
            categoryID: otherID
        )
        let excludedIncome = CurrentLedgerTransaction(
            type: .income,
            amountInCents: 8_000,
            date: referenceDate,
            categoryID: foodID
        )
        (matchingTransactions + [excludedByCategory, excludedIncome]).forEach(context.insert)
        try context.save()

        let filters = TransactionSearchFilters(
            type: .expense,
            categoryID: foodID,
            startDate: try makeDate(year: 2026, month: 8, day: 1, calendar: calendar),
            endDate: try makeDate(year: 2026, month: 8, day: 31, calendar: calendar),
            minimumAmountInCents: 1_500,
            maximumAmountInCents: 4_000
        )
        let result = try TransactionSearchService.search(
            keyword: "",
            filters: filters,
            sortOrder: .amount,
            limit: 2,
            in: context,
            relativeTo: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(result.totalCount, 3)
        XCTAssertEqual(result.transactions.map(\.amountInCents), [4_000, 3_000])
    }

    func testAnyNoncurrentMatchMakesEveryResultUseYear() throws {
        let context = try makeContext()
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 25, calendar: calendar)
        let categoryID = UUID()
        context.insert(
            transaction(
                amount: 1_000,
                date: try makeDate(year: 2026, month: 8, day: 25, calendar: calendar),
                categoryID: categoryID
            )
        )
        context.insert(
            transaction(
                amount: 2_000,
                date: try makeDate(year: 2025, month: 12, day: 31, calendar: calendar),
                categoryID: categoryID
            )
        )
        try context.save()

        let result = try TransactionSearchService.search(
            keyword: "",
            filters: TransactionSearchFilters(),
            sortOrder: .time,
            limit: 100,
            in: context,
            relativeTo: referenceDate,
            calendar: calendar
        )

        XCTAssertTrue(result.showsYear)
    }

    func testKeywordAndEveryFilterAreCombinedWithAndSemantics() throws {
        let context = try makeContext()
        let calendar = makeCalendar()
        let categoryID = UUID()
        let matching = transaction(
            amount: 2_500,
            date: try makeDate(year: 2026, month: 8, day: 20, calendar: calendar),
            note: "超市采购",
            categoryID: categoryID
        )
        let wrongCategory = transaction(
            amount: 2_500,
            date: try makeDate(year: 2026, month: 8, day: 20, calendar: calendar),
            note: "超市采购",
            categoryID: UUID()
        )
        let wrongAmount = transaction(
            amount: 5_000,
            date: try makeDate(year: 2026, month: 8, day: 20, calendar: calendar),
            note: "超市采购",
            categoryID: categoryID
        )
        [matching, wrongCategory, wrongAmount].forEach(context.insert)
        try context.save()

        let result = try TransactionSearchService.search(
            keyword: "超市",
            filters: TransactionSearchFilters(
                type: .expense,
                categoryID: categoryID,
                startDate: try makeDate(
                    year: 2026,
                    month: 8,
                    day: 1,
                    calendar: calendar
                ),
                endDate: try makeDate(
                    year: 2026,
                    month: 8,
                    day: 31,
                    calendar: calendar
                ),
                minimumAmountInCents: 2_000,
                maximumAmountInCents: 3_000
            ),
            sortOrder: .time,
            limit: 100,
            in: context,
            calendar: calendar
        )

        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(result.transactions.map(\.id), [matching.id])
    }

    private func makeContext() throws -> ModelContext {
        let schema = TallyModelContainerFactory.currentSchema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try TallyModelContainerFactory.make(configuration: configuration)
        return ModelContext(container)
    }

    private func transaction(
        amount: Int64,
        date: Date,
        note: String = "",
        categoryID: UUID,
        subcategoryID: UUID? = nil
    ) -> CurrentLedgerTransaction {
        CurrentLedgerTransaction(
            type: .expense,
            amountInCents: amount,
            date: date,
            note: note,
            categoryID: categoryID,
            subcategoryID: subcategoryID
        )
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        )
    }
}
