//
//  TransactionDayTitleTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

final class TransactionDayTitleTests: XCTestCase {
    func testTodayOnlyAddsTodayMarker() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 22, calendar: calendar)

        XCTAssertEqual(
            TransactionDayTitle.text(
                for: referenceDate,
                relativeTo: referenceDate,
                calendar: calendar
            ),
            "8月22日 今天"
        )
    }

    func testYesterdayAddsYesterdayAndWeekday() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 22, calendar: calendar)
        let yesterday = try makeDate(year: 2026, month: 8, day: 21, calendar: calendar)

        XCTAssertEqual(
            TransactionDayTitle.text(
                for: yesterday,
                relativeTo: referenceDate,
                calendar: calendar
            ),
            "8月21日 昨天 星期五"
        )
    }

    func testOlderDateOnlyAddsWeekday() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 22, calendar: calendar)
        let olderDate = try makeDate(year: 2026, month: 8, day: 20, calendar: calendar)

        XCTAssertEqual(
            TransactionDayTitle.text(
                for: olderDate,
                relativeTo: referenceDate,
                calendar: calendar
            ),
            "8月20日 星期四"
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
