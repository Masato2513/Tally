//
//  StatisticsServiceTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class StatisticsServiceTests: XCTestCase {
    func testMonthlySummaryIncludesOnlyTheSelectedMonth() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 21, calendar: calendar)
        let categoryID = UUID()
        let transactions = [
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: 2_800,
                date: try makeDate(year: 2026, month: 8, day: 1, calendar: calendar),
                categoryID: categoryID
            ),
            CurrentLedgerTransaction(
                type: .income,
                amountInCents: 1_200_000,
                date: try makeDate(year: 2026, month: 8, day: 20, calendar: calendar),
                categoryID: categoryID
            ),
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: 9_900,
                date: try makeDate(year: 2026, month: 7, day: 31, calendar: calendar),
                categoryID: categoryID
            ),
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: 8_800,
                date: try makeDate(year: 2026, month: 9, day: 1, calendar: calendar),
                categoryID: categoryID
            )
        ]

        let summary = StatisticsService.monthlySummary(
            for: transactions,
            containing: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(summary.expenseInCents, 2_800)
        XCTAssertEqual(summary.incomeInCents, 1_200_000)
        XCTAssertEqual(summary.balanceInCents, 1_197_200)
    }

    func testLastThreeDaysUsesNaturalDayBoundaries() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(
            year: 2026,
            month: 8,
            day: 21,
            hour: 12,
            calendar: calendar
        )
        let categoryID = UUID()
        let includedDates = [
            try makeDate(year: 2026, month: 8, day: 19, calendar: calendar),
            try makeDate(year: 2026, month: 8, day: 20, hour: 23, calendar: calendar),
            try makeDate(year: 2026, month: 8, day: 21, hour: 8, calendar: calendar)
        ]
        let excludedDates = [
            try makeDate(year: 2026, month: 8, day: 18, hour: 23, calendar: calendar),
            try makeDate(year: 2026, month: 8, day: 22, calendar: calendar)
        ]
        let transactions = (includedDates + excludedDates).map {
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: 100,
                date: $0,
                categoryID: categoryID
            )
        }

        let recentTransactions = StatisticsService.transactionsWithinLastDays(
            3,
            from: transactions,
            relativeTo: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(recentTransactions.map(\.date), includedDates.sorted(by: >))
    }

    func testExpenseTotalExcludesIncome() {
        let categoryID = UUID()
        let transactions = [
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: 500,
                date: .now,
                categoryID: categoryID
            ),
            CurrentLedgerTransaction(
                type: .income,
                amountInCents: 10_000,
                date: .now,
                categoryID: categoryID
            ),
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: 700,
                date: .now,
                categoryID: categoryID
            )
        ]

        XCTAssertEqual(StatisticsService.expenseTotal(for: transactions), 1_200)
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
        hour: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: year, month: month, day: day, hour: hour)
            )
        )
    }
}
