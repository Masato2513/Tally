//
//  BillsServiceTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class BillsServiceTests: XCTestCase {
    func testTimeSortFiltersSelectedMonthAndOrdersNewestFirst() throws {
        let calendar = makeCalendar()
        let categoryID = UUID()
        let julyTransaction = transaction(
            amount: 9_900,
            date: try makeDate(year: 2026, month: 7, day: 31, calendar: calendar),
            categoryID: categoryID
        )
        let augustOlder = transaction(
            amount: 1_200,
            date: try makeDate(year: 2026, month: 8, day: 2, calendar: calendar),
            categoryID: categoryID
        )
        let augustNewer = transaction(
            amount: 600,
            date: try makeDate(year: 2026, month: 8, day: 20, calendar: calendar),
            categoryID: categoryID
        )
        let septemberTransaction = transaction(
            amount: 8_800,
            date: try makeDate(year: 2026, month: 9, day: 1, calendar: calendar),
            categoryID: categoryID
        )

        let result = BillsService.transactions(
            inMonthContaining: augustNewer.date,
            from: [julyTransaction, augustOlder, augustNewer, septemberTransaction],
            sortedBy: .time,
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.id), [augustNewer.id, augustOlder.id])
    }

    func testAmountSortUsesDateToBreakEqualAmountTies() throws {
        let calendar = makeCalendar()
        let categoryID = UUID()
        let smallest = transaction(
            amount: 600,
            date: try makeDate(year: 2026, month: 8, day: 21, calendar: calendar),
            categoryID: categoryID
        )
        let equalAmountOlder = transaction(
            amount: 2_800,
            date: try makeDate(year: 2026, month: 8, day: 10, calendar: calendar),
            categoryID: categoryID
        )
        let equalAmountNewer = transaction(
            amount: 2_800,
            date: try makeDate(year: 2026, month: 8, day: 20, calendar: calendar),
            categoryID: categoryID
        )

        let result = BillsService.transactions(
            inMonthContaining: smallest.date,
            from: [smallest, equalAmountOlder, equalAmountNewer],
            sortedBy: .amount,
            calendar: calendar
        )

        XCTAssertEqual(
            result.map(\.id),
            [equalAmountNewer.id, equalAmountOlder.id, smallest.id]
        )
    }

    private func transaction(
        amount: Int64,
        date: Date,
        categoryID: UUID
    ) -> CurrentLedgerTransaction {
        CurrentLedgerTransaction(
            type: .expense,
            amountInCents: amount,
            date: date,
            categoryID: categoryID
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
