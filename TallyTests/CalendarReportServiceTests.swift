//
//  CalendarReportServiceTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class CalendarReportServiceTests: XCTestCase {
    func testLeadingBlankCountRespectsCalendarsFirstWeekday() throws {
        var mondayFirst = makeCalendar()
        mondayFirst.firstWeekday = 2
        var sundayFirst = makeCalendar()
        sundayFirst.firstWeekday = 1
        let august = try makeDate(
            year: 2026,
            month: 8,
            day: 15,
            calendar: mondayFirst
        )

        XCTAssertEqual(
            CalendarReportService.leadingBlankCount(
                forMonthContaining: august,
                calendar: mondayFirst
            ),
            5
        )
        XCTAssertEqual(
            CalendarReportService.leadingBlankCount(
                forMonthContaining: august,
                calendar: sundayFirst
            ),
            6
        )
    }

    func testWeekdaySymbolsStartAtCalendarsFirstWeekday() {
        var calendar = makeCalendar()
        calendar.firstWeekday = 2

        let symbols = CalendarReportService.orderedVeryShortWeekdaySymbols(calendar: calendar)

        XCTAssertEqual(symbols.count, 7)
        XCTAssertEqual(symbols.first, calendar.veryShortStandaloneWeekdaySymbols[1])
        XCTAssertEqual(symbols.last, calendar.veryShortStandaloneWeekdaySymbols[0])
    }

    func testDaySummariesFillLeapMonthAndOnlyAggregateExpenses() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2024, month: 2, day: 15, calendar: calendar)
        let categoryID = UUID()
        let transactions = [
            transaction(
                type: .expense,
                amount: 1_200,
                date: try makeDate(year: 2024, month: 2, day: 2, calendar: calendar),
                categoryID: categoryID
            ),
            transaction(
                type: .expense,
                amount: 800,
                date: try makeDate(year: 2024, month: 2, day: 2, hour: 20, calendar: calendar),
                categoryID: categoryID
            ),
            transaction(
                type: .income,
                amount: 20_000,
                date: try makeDate(year: 2024, month: 2, day: 2, calendar: calendar),
                categoryID: categoryID
            )
        ]

        let summaries = CalendarReportService.daySummaries(
            for: transactions,
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(summaries.count, 29)
        XCTAssertEqual(summaries[1].expenseInCents, 2_000)
        XCTAssertEqual(summaries.filter { $0.expenseInCents == 0 }.count, 28)
    }

    func testMonthSnapshotDerivesTotalAndMaximumFromOneSetOfSummaries() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 22, calendar: calendar)
        let categoryID = UUID()
        let transactions = [
            transaction(
                type: .expense,
                amount: 1_200,
                date: try makeDate(year: 2026, month: 8, day: 2, calendar: calendar),
                categoryID: categoryID
            ),
            transaction(
                type: .expense,
                amount: 3_400,
                date: try makeDate(year: 2026, month: 8, day: 8, calendar: calendar),
                categoryID: categoryID
            ),
            transaction(
                type: .income,
                amount: 99_000,
                date: referenceDate,
                categoryID: categoryID
            )
        ]

        let snapshot = CalendarReportService.monthSnapshot(
            for: transactions,
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.daySummaries.count, 31)
        XCTAssertEqual(snapshot.monthlyExpenseInCents, 4_600)
        XCTAssertEqual(snapshot.maximumDailyExpenseInCents, 3_400)
    }

    func testTransactionsOnDayUseNaturalDayBoundariesAndNewestFirst() throws {
        let calendar = makeCalendar()
        let selectedDay = try makeDate(year: 2026, month: 8, day: 21, hour: 12, calendar: calendar)
        let categoryID = UUID()
        let early = transaction(
            type: .expense,
            amount: 100,
            date: try makeDate(year: 2026, month: 8, day: 21, calendar: calendar),
            categoryID: categoryID
        )
        let late = transaction(
            type: .expense,
            amount: 200,
            date: try makeDate(year: 2026, month: 8, day: 21, hour: 23, calendar: calendar),
            categoryID: categoryID
        )
        let nextDay = transaction(
            type: .expense,
            amount: 300,
            date: try makeDate(year: 2026, month: 8, day: 22, calendar: calendar),
            categoryID: categoryID
        )

        let result = CalendarReportService.transactions(
            onDayContaining: selectedDay,
            from: [early, nextDay, late],
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.id), [late.id, early.id])
    }

    func testRecordDateUsesSelectedDayAndCurrentTime() throws {
        let calendar = makeCalendar()
        let day = try makeDate(year: 2026, month: 8, day: 3, calendar: calendar)
        let current = try makeDate(
            year: 2026,
            month: 8,
            day: 21,
            hour: 16,
            minute: 42,
            calendar: calendar
        )

        let result = CalendarReportService.recordDate(
            on: day,
            relativeTo: current,
            calendar: calendar
        )
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: result
        )

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 3)
        XCTAssertEqual(components.hour, 16)
        XCTAssertEqual(components.minute, 42)
    }

    func testRelativeIntensityIsClampedAndHandlesZero() {
        XCTAssertEqual(
            CalendarReportService.relativeIntensity(amountInCents: 0, maximumInCents: 1_000),
            0
        )
        XCTAssertEqual(
            CalendarReportService.relativeIntensity(amountInCents: 500, maximumInCents: 1_000),
            0.5
        )
        XCTAssertEqual(
            CalendarReportService.relativeIntensity(amountInCents: 2_000, maximumInCents: 1_000),
            1
        )
    }

    private func transaction(
        type: LedgerTransactionType,
        amount: Int64,
        date: Date,
        categoryID: UUID
    ) -> LedgerTransaction {
        LedgerTransaction(
            type: type,
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
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(
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
