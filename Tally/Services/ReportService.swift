//
//  ReportService.swift
//  Tally
//

import Foundation

struct ExpenseCategorySlice: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let symbolName: String
    let amountInCents: Int64
    let categoryIDs: [UUID]
    let isMerged: Bool

    func percentage(of totalInCents: Int64) -> Double {
        guard totalInCents > 0 else { return 0 }
        return Double(amountInCents) / Double(totalInCents)
    }
}

struct ReportDetailItem: Identifiable, Equatable {
    let id: String
    let name: String
    let amountInCents: Int64

    func percentage(of totalInCents: Int64) -> Double {
        guard totalInCents > 0 else { return 0 }
        return Double(amountInCents) / Double(totalInCents)
    }
}

struct DailyExpensePoint: Identifiable, Equatable {
    let date: Date
    let amountInCents: Int64

    var id: Date { date }

    var amountInYuan: Double {
        Double(amountInCents) / 100
    }
}

struct MonthlyReportSnapshot: Equatable {
    let summary: MonthlyLedgerSummary
    let categorySlices: [ExpenseCategorySlice]
    let dailyExpensePoints: [DailyExpensePoint]
}

enum ReportService {
    static func categorySlice(
        at accumulatedValue: Double,
        in slices: [ExpenseCategorySlice]
    ) -> ExpenseCategorySlice? {
        guard accumulatedValue >= 0 else { return nil }

        var accumulated = 0.0
        for slice in slices {
            accumulated += Double(slice.amountInCents)
            if accumulatedValue <= accumulated {
                return slice
            }
        }
        return nil
    }

    static func monthlySnapshot(
        for transactions: [LedgerTransaction],
        categories: [LedgerCategory],
        inMonthContaining date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> MonthlyReportSnapshot {
        MonthlyReportSnapshot(
            summary: StatisticsService.monthlySummary(
                for: transactions,
                containing: date,
                calendar: calendar
            ),
            categorySlices: expenseCategorySlices(
                for: transactions,
                categories: categories,
                inMonthContaining: date,
                calendar: calendar
            ),
            dailyExpensePoints: dailyExpensePoints(
                for: transactions,
                inMonthContaining: date,
                calendar: calendar
            )
        )
    }

    static func expenseCategorySlices(
        for transactions: [LedgerTransaction],
        categories: [LedgerCategory],
        inMonthContaining date: Date,
        maximumSliceCount: Int = 6,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [ExpenseCategorySlice] {
        guard
            maximumSliceCount > 0,
            let interval = CalendarIntervals.month(containing: date, calendar: calendar)
        else {
            return []
        }

        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let expenses = transactions.filter {
            $0.type == .expense && interval.contains($0.date)
        }
        let grouped = Dictionary(grouping: expenses, by: \.categoryID)

        let sortedSlices = grouped.compactMap { categoryID, transactions -> ExpenseCategorySlice? in
            let amount = safeSum(transactions.map(\.amountInCents))
            guard amount > 0 else { return nil }
            let category = categoryByID[categoryID]
            return ExpenseCategorySlice(
                id: "category:\(categoryID.uuidString)",
                name: category?.name ?? "未分类",
                symbolName: category?.symbolName ?? "questionmark.circle",
                amountInCents: amount,
                categoryIDs: [categoryID],
                isMerged: false
            )
        }
        .sorted { lhs, rhs in
            if lhs.amountInCents != rhs.amountInCents {
                return lhs.amountInCents > rhs.amountInCents
            }

            let lhsOrder = lhs.categoryIDs.first.flatMap { categoryByID[$0]?.sortOrder } ?? .max
            let rhsOrder = rhs.categoryIDs.first.flatMap { categoryByID[$0]?.sortOrder } ?? .max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.id < rhs.id
        }

        guard sortedSlices.count > maximumSliceCount else { return sortedSlices }
        guard maximumSliceCount > 1 else {
            return [mergedSlice(from: sortedSlices)]
        }

        let retainedCount = maximumSliceCount - 1
        let retained = Array(sortedSlices.prefix(retainedCount))
        let merged = mergedSlice(from: Array(sortedSlices.dropFirst(retainedCount)))
        return retained + [merged]
    }

    static func detailItems(
        for slice: ExpenseCategorySlice,
        transactions: [LedgerTransaction],
        categories: [LedgerCategory],
        subcategories: [LedgerSubcategory],
        inMonthContaining date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [ReportDetailItem] {
        guard let interval = CalendarIntervals.month(containing: date, calendar: calendar) else {
            return []
        }

        let categoryIDs = Set(slice.categoryIDs)
        let matchingTransactions = transactions.filter {
            $0.type == .expense
                && interval.contains($0.date)
                && categoryIDs.contains($0.categoryID)
        }

        if slice.isMerged {
            let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            return Dictionary(grouping: matchingTransactions, by: \.categoryID)
                .map { categoryID, transactions in
                    ReportDetailItem(
                        id: "category:\(categoryID.uuidString)",
                        name: categoryByID[categoryID]?.name ?? "未分类",
                        amountInCents: safeSum(transactions.map(\.amountInCents))
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.amountInCents != rhs.amountInCents {
                        return lhs.amountInCents > rhs.amountInCents
                    }
                    return lhs.id < rhs.id
                }
        }

        let subcategoryByID = Dictionary(uniqueKeysWithValues: subcategories.map { ($0.id, $0) })
        return Dictionary(grouping: matchingTransactions, by: \.subcategoryID)
            .map { subcategoryID, transactions in
                let id = subcategoryID.map { "subcategory:\($0.uuidString)" } ?? "uncategorized"
                return ReportDetailItem(
                    id: id,
                    name: subcategoryID.flatMap { subcategoryByID[$0]?.name } ?? "未细分",
                    amountInCents: safeSum(transactions.map(\.amountInCents))
                )
            }
            .sorted { lhs, rhs in
                if lhs.amountInCents != rhs.amountInCents {
                    return lhs.amountInCents > rhs.amountInCents
                }
                return lhs.id < rhs.id
            }
    }

    static func dailyExpensePoints(
        for transactions: [LedgerTransaction],
        inMonthContaining date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [DailyExpensePoint] {
        guard let monthInterval = CalendarIntervals.month(containing: date, calendar: calendar) else {
            return []
        }

        let monthlyExpenses = transactions.filter {
            $0.type == .expense && monthInterval.contains($0.date)
        }
        let amountsByDay = Dictionary(grouping: monthlyExpenses) {
            calendar.startOfDay(for: $0.date)
        }
        .mapValues { safeSum($0.map(\.amountInCents)) }

        var points: [DailyExpensePoint] = []
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            let day = calendar.startOfDay(for: currentDate)
            points.append(
                DailyExpensePoint(date: day, amountInCents: amountsByDay[day] ?? 0)
            )

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        return points
    }
}

private extension ReportService {
    static func mergedSlice(from slices: [ExpenseCategorySlice]) -> ExpenseCategorySlice {
        ExpenseCategorySlice(
            id: "other",
            name: "其他",
            symbolName: "ellipsis.circle",
            amountInCents: safeSum(slices.map(\.amountInCents)),
            categoryIDs: slices.flatMap(\.categoryIDs),
            isMerged: true
        )
    }

    static func safeSum<S: Sequence>(_ values: S) -> Int64 where S.Element == Int64 {
        values.reduce(into: 0) { result, value in
            let (sum, overflow) = result.addingReportingOverflow(value)
            result = overflow ? Int64.max : sum
        }
    }
}
