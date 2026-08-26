//
//  TransactionExportServiceTests.swift
//  TallyTests
//

import SwiftData
import XCTest
@testable import Tally

@MainActor
final class TransactionExportServiceTests: XCTestCase {
    func testExportsInclusiveEndDateWithBOMAndHistoricalCategoryNames() throws {
        let context = try makeContext()
        let calendar = makeCalendar()
        let category = CurrentLedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        let subcategory = CurrentLedgerSubcategory(
            name: "咖啡",
            categoryID: category.id,
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        let incomeCategory = CurrentLedgerCategory(
            name: "工资",
            type: .income,
            symbolName: "banknote",
            sortOrder: 0,
            isSystem: false,
            isHidden: true
        )
        let expense = CurrentLedgerTransaction(
            type: .expense,
            amountInCents: 1_740,
            date: try makeDate(
                year: 2026,
                month: 8,
                day: 1,
                hour: 8,
                minute: 30,
                calendar: calendar
            ),
            note: "早餐, \"拿铁\"\n少糖",
            categoryID: category.id,
            subcategoryID: subcategory.id
        )
        let income = CurrentLedgerTransaction(
            type: .income,
            amountInCents: 10_000,
            date: try makeDate(
                year: 2026,
                month: 8,
                day: 25,
                hour: 23,
                minute: 59,
                calendar: calendar
            ),
            categoryID: incomeCategory.id
        )
        let excluded = CurrentLedgerTransaction(
            type: .expense,
            amountInCents: 500,
            date: try makeDate(
                year: 2026,
                month: 8,
                day: 26,
                hour: 0,
                minute: 0,
                calendar: calendar
            ),
            categoryID: category.id
        )
        [category, incomeCategory].forEach(context.insert)
        context.insert(subcategory)
        [expense, income, excluded].forEach(context.insert)
        try context.save()

        let payload = try XCTUnwrap(
            TransactionExportService.makePayload(
                from: try makeDate(
                    year: 2026,
                    month: 8,
                    day: 1,
                    calendar: calendar
                ),
                through: try makeDate(
                    year: 2026,
                    month: 8,
                    day: 25,
                    calendar: calendar
                ),
                in: context,
                calendar: calendar
            )
        )

        XCTAssertEqual(payload.transactionCount, 2)
        XCTAssertEqual(payload.fileName, "记账_20260801-20260825.csv")
        XCTAssertEqual(payload.data.prefix(3), Data([0xEF, 0xBB, 0xBF]))

        let csv = try XCTUnwrap(
            String(data: payload.data.dropFirst(3), encoding: .utf8)
        )
        XCTAssertEqual(
            csv,
            [
                "日期,类型,分类,子分类,金额,备注",
                "2026-08-01 08:30:00,支出,餐饮,咖啡,17.40,\"早餐, \"\"拿铁\"\"\n少糖\"",
                "2026-08-25 23:59:00,收入,工资,,100.00,"
            ].joined(separator: "\r\n")
        )
    }

    func testReturnsNilInsteadOfCreatingAnEmptyExport() throws {
        let context = try makeContext()
        let calendar = makeCalendar()
        let date = try makeDate(
            year: 2026,
            month: 8,
            day: 25,
            calendar: calendar
        )

        XCTAssertNil(
            try TransactionExportService.makePayload(
                from: date,
                through: date,
                in: context,
                calendar: calendar
            )
        )
    }

    private func makeContext() throws -> ModelContext {
        let schema = TallyModelContainerFactory.currentSchema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try TallyModelContainerFactory.make(
            configuration: configuration
        )
        return ModelContext(container)
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
