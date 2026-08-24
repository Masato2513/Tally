//
//  CalendarIntervalsTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

final class CalendarIntervalsTests: XCTestCase {
    func testMonthIntervalHandlesLeapYear() throws {
        let calendar = makeCalendar()
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 10)))
        let interval = try XCTUnwrap(CalendarIntervals.month(containing: date, calendar: calendar))

        XCTAssertEqual(
            interval.start,
            calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))
        )
        XCTAssertEqual(
            interval.end,
            calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))
        )
    }

    func testDayIntervalUsesTheProvidedTimeZone() throws {
        let calendar = makeCalendar()
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 18, minute: 30))
        )
        let interval = try XCTUnwrap(CalendarIntervals.day(containing: date, calendar: calendar))

        XCTAssertEqual(
            interval.start,
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))
        )
        XCTAssertEqual(
            interval.end,
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 22))
        )
    }

    func testMonthAndRecentDaysUsesMonthWhenRecentDaysAreInsideIt() throws {
        let calendar = makeCalendar()
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 22, hour: 14))
        )
        let interval = try XCTUnwrap(
            CalendarIntervals.monthAndRecentDays(3, containing: date, calendar: calendar)
        )

        XCTAssertEqual(
            interval.start,
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))
        )
        XCTAssertEqual(
            interval.end,
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
    }

    func testMonthAndRecentDaysIncludesPreviousMonthAtBoundary() throws {
        let calendar = makeCalendar()
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 14))
        )
        let interval = try XCTUnwrap(
            CalendarIntervals.monthAndRecentDays(3, containing: date, calendar: calendar)
        )

        XCTAssertEqual(
            interval.start,
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))
        )
        XCTAssertEqual(
            interval.end,
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }
}
