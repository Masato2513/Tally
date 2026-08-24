//
//  ReportServiceTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class ReportServiceTests: XCTestCase {
    func testAccumulatedChartValueSelectsTheExpectedCategorySlice() {
        let slices = [
            ExpenseCategorySlice(
                id: "food",
                name: "餐饮",
                symbolName: "fork.knife",
                amountInCents: 1_000,
                categoryIDs: [UUID()],
                isMerged: false
            ),
            ExpenseCategorySlice(
                id: "shopping",
                name: "购物",
                symbolName: "bag",
                amountInCents: 2_000,
                categoryIDs: [UUID()],
                isMerged: false
            )
        ]

        XCTAssertEqual(ReportService.categorySlice(at: 0, in: slices)?.id, "food")
        XCTAssertEqual(ReportService.categorySlice(at: 1_000, in: slices)?.id, "food")
        XCTAssertEqual(ReportService.categorySlice(at: 1_001, in: slices)?.id, "shopping")
        XCTAssertEqual(ReportService.categorySlice(at: 3_000, in: slices)?.id, "shopping")
        XCTAssertNil(ReportService.categorySlice(at: 3_001, in: slices))
        XCTAssertNil(ReportService.categorySlice(at: -1, in: slices))
    }

    func testCategorySlicesKeepTopFiveAndMergeTheRest() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 21, calendar: calendar)
        let categories = (0..<8).map { index in
            CurrentLedgerCategory(
                name: "分类\(index + 1)",
                type: .expense,
                symbolName: "circle",
                sortOrder: index,
                isSystem: false
            )
        }
        let amounts: [Int64] = [8_000, 7_000, 6_000, 5_000, 4_000, 3_000, 2_000, 1_000]
        var transactions = try zip(categories, amounts).enumerated().map { index, pair in
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: pair.1,
                date: try makeDate(
                    year: 2026,
                    month: 8,
                    day: index + 1,
                    calendar: calendar
                ),
                categoryID: pair.0.id
            )
        }
        transactions.append(
            CurrentLedgerTransaction(
                type: .income,
                amountInCents: 99_000,
                date: referenceDate,
                categoryID: categories[0].id
            )
        )
        transactions.append(
            CurrentLedgerTransaction(
                type: .expense,
                amountInCents: 88_000,
                date: try makeDate(year: 2026, month: 7, day: 31, calendar: calendar),
                categoryID: categories[0].id
            )
        )

        let slices = ReportService.expenseCategorySlices(
            for: transactions,
            categories: categories,
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(slices.count, 6)
        XCTAssertEqual(slices.prefix(5).map(\.name), ["分类1", "分类2", "分类3", "分类4", "分类5"])
        XCTAssertEqual(slices.last?.name, "其他")
        XCTAssertEqual(slices.last?.amountInCents, 6_000)
        XCTAssertEqual(Set(slices.last?.categoryIDs ?? []), Set(categories.suffix(3).map(\.id)))
        XCTAssertEqual(slices.reduce(0) { $0 + $1.amountInCents }, 36_000)
    }

    func testCategoryDetailsGroupSubcategoriesAndUnspecifiedTransactions() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 21, calendar: calendar)
        let food = CurrentLedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: false
        )
        let meals = CurrentLedgerSubcategory(
            name: "三餐",
            categoryID: food.id,
            sortOrder: 0,
            isSystem: false
        )
        let coffee = CurrentLedgerSubcategory(
            name: "咖啡",
            categoryID: food.id,
            sortOrder: 1,
            isSystem: false
        )
        let transactions = [
            transaction(amount: 2_800, date: referenceDate, categoryID: food.id, subcategoryID: meals.id),
            transaction(amount: 2_200, date: referenceDate, categoryID: food.id, subcategoryID: meals.id),
            transaction(amount: 1_800, date: referenceDate, categoryID: food.id, subcategoryID: coffee.id),
            transaction(amount: 600, date: referenceDate, categoryID: food.id)
        ]
        let slice = try XCTUnwrap(
            ReportService.expenseCategorySlices(
                for: transactions,
                categories: [food],
                inMonthContaining: referenceDate,
                calendar: calendar
            ).first
        )

        let details = ReportService.detailItems(
            for: slice,
            transactions: transactions,
            categories: [food],
            subcategories: [meals, coffee],
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(details.map(\.name), ["餐饮 · 三餐", "餐饮 · 咖啡", "餐饮"])
        XCTAssertEqual(details.map(\.amountInCents), [5_000, 1_800, 600])
        XCTAssertEqual(
            details[0].percentage(of: slice.amountInCents),
            5_000.0 / 7_400.0,
            accuracy: 0.000_001
        )
    }

    func testMergedCategoryDetailsKeepEachCategoryHierarchySeparate() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 21, calendar: calendar)
        let food = CurrentLedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true
        )
        let shopping = CurrentLedgerCategory(
            name: "购物",
            type: .expense,
            symbolName: "bag",
            sortOrder: 1,
            isSystem: true
        )
        let meals = CurrentLedgerSubcategory(
            name: "三餐",
            categoryID: food.id,
            sortOrder: 0,
            isSystem: true
        )
        let transactions = [
            transaction(
                amount: 1_500,
                date: referenceDate,
                categoryID: shopping.id
            ),
            transaction(
                amount: 1_000,
                date: referenceDate,
                categoryID: food.id,
                subcategoryID: meals.id
            ),
            transaction(
                amount: 500,
                date: referenceDate,
                categoryID: food.id
            )
        ]
        let slice = ExpenseCategorySlice(
            id: "other",
            name: "其他",
            symbolName: "ellipsis.circle",
            amountInCents: 3_000,
            categoryIDs: [food.id, shopping.id],
            isMerged: true
        )

        let details = ReportService.detailItems(
            for: slice,
            transactions: transactions,
            categories: [food, shopping],
            subcategories: [meals],
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(details.map(\.name), ["购物", "餐饮 · 三餐", "餐饮"])
        XCTAssertEqual(details.map(\.amountInCents), [1_500, 1_000, 500])
    }

    func testDailyExpensePointsFillEveryDayOfLeapMonthWithZeros() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2024, month: 2, day: 15, calendar: calendar)
        let categoryID = UUID()
        let transactions = [
            transaction(
                amount: 1_200,
                date: try makeDate(year: 2024, month: 2, day: 2, calendar: calendar),
                categoryID: categoryID
            ),
            transaction(
                amount: 800,
                date: try makeDate(year: 2024, month: 2, day: 2, calendar: calendar),
                categoryID: categoryID
            ),
            transaction(
                amount: 2_900,
                date: try makeDate(year: 2024, month: 2, day: 29, calendar: calendar),
                categoryID: categoryID
            ),
            CurrentLedgerTransaction(
                type: .income,
                amountInCents: 50_000,
                date: try makeDate(year: 2024, month: 2, day: 3, calendar: calendar),
                categoryID: categoryID
            )
        ]

        let points = ReportService.dailyExpensePoints(
            for: transactions,
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(points.count, 29)
        XCTAssertEqual(points[1].amountInCents, 2_000)
        XCTAssertEqual(points[2].amountInCents, 0)
        XCTAssertEqual(points[28].amountInCents, 2_900)
        XCTAssertEqual(points.filter { $0.amountInCents == 0 }.count, 27)
    }

    func testReportCalculationsExcludeTheExactStartOfNextMonth() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 15, calendar: calendar)
        let category = CurrentLedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true
        )
        let augustTransaction = transaction(
            amount: 1_000,
            date: try makeDate(year: 2026, month: 8, day: 31, calendar: calendar),
            categoryID: category.id
        )
        let septemberTransaction = transaction(
            amount: 9_000,
            date: try makeDate(year: 2026, month: 9, day: 1, calendar: calendar),
            categoryID: category.id
        )
        let transactions = [augustTransaction, septemberTransaction]

        let slices = ReportService.expenseCategorySlices(
            for: transactions,
            categories: [category],
            inMonthContaining: referenceDate,
            calendar: calendar
        )
        let points = ReportService.dailyExpensePoints(
            for: transactions,
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(slices.map(\.amountInCents), [1_000])
        XCTAssertEqual(points.map(\.amountInCents).reduce(0, +), 1_000)
    }

    func testNearestDailyExpensePointSnapsToClosestDateIncludingZeroDays() throws {
        let calendar = makeCalendar()
        let points = [
            DailyExpensePoint(
                date: try makeDate(year: 2026, month: 8, day: 21, calendar: calendar),
                amountInCents: 1_200
            ),
            DailyExpensePoint(
                date: try makeDate(year: 2026, month: 8, day: 22, calendar: calendar),
                amountInCents: 0
            ),
            DailyExpensePoint(
                date: try makeDate(year: 2026, month: 8, day: 23, calendar: calendar),
                amountInCents: 3_400
            )
        ]
        let dateNearZeroDay = try XCTUnwrap(
            calendar.date(
                byAdding: .hour,
                value: 3,
                to: points[1].date
            )
        )

        let selected = ReportService.nearestDailyExpensePoint(
            to: dateNearZeroDay,
            in: points
        )

        XCTAssertEqual(selected, points[1])
        XCTAssertEqual(selected?.amountInCents, 0)
        XCTAssertNil(ReportService.nearestDailyExpensePoint(to: dateNearZeroDay, in: []))
    }

    func testMonthlySnapshotKeepsSummarySlicesAndDailyPointsConsistent() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 22, calendar: calendar)
        let category = CurrentLedgerCategory(
            name: "餐饮",
            type: .expense,
            symbolName: "fork.knife",
            sortOrder: 0,
            isSystem: true
        )
        let transactions = [
            transaction(
                amount: 1_200,
                date: try makeDate(year: 2026, month: 8, day: 2, calendar: calendar),
                categoryID: category.id
            ),
            transaction(
                amount: 800,
                date: try makeDate(year: 2026, month: 8, day: 2, calendar: calendar),
                categoryID: category.id
            ),
            CurrentLedgerTransaction(
                type: .income,
                amountInCents: 5_000,
                date: referenceDate,
                categoryID: category.id
            )
        ]

        let snapshot = ReportService.monthlySnapshot(
            for: transactions,
            categories: [category],
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.summary.expenseInCents, 2_000)
        XCTAssertEqual(snapshot.summary.incomeInCents, 5_000)
        XCTAssertEqual(snapshot.categorySlices.map(\.amountInCents), [2_000])
        XCTAssertEqual(snapshot.dailyExpensePoints[1].amountInCents, 2_000)
    }

    func testDeletedAndRecreatedSameNameCategoriesRemainSeparateSlices() throws {
        let calendar = makeCalendar()
        let referenceDate = try makeDate(year: 2026, month: 8, day: 22, calendar: calendar)
        let deletedCategory = CurrentLedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .mint,
            sortOrder: 0,
            isSystem: false,
            isSoftDeleted: true
        )
        let recreatedCategory = CurrentLedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .mint,
            sortOrder: 1,
            isSystem: false
        )
        let transactions = [
            transaction(
                amount: 2_800,
                date: referenceDate,
                categoryID: deletedCategory.id
            ),
            transaction(
                amount: 1_200,
                date: referenceDate,
                categoryID: recreatedCategory.id
            )
        ]

        let slices = ReportService.expenseCategorySlices(
            for: transactions,
            categories: [deletedCategory, recreatedCategory],
            inMonthContaining: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices.map(\.name), ["宠物", "宠物"])
        XCTAssertEqual(
            Set(slices.flatMap(\.categoryIDs)),
            Set([deletedCategory.id, recreatedCategory.id])
        )
        XCTAssertEqual(slices.map(\.amountInCents), [2_800, 1_200])
    }

    private func transaction(
        amount: Int64,
        date: Date,
        categoryID: UUID,
        subcategoryID: UUID? = nil
    ) -> CurrentLedgerTransaction {
        CurrentLedgerTransaction(
            type: .expense,
            amountInCents: amount,
            date: date,
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
