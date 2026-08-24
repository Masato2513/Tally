//
//  ReportCategoryDetailView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct ReportCategoryDetailView: View {
    @Query(sort: \LedgerCategory.sortOrder)
    private var categories: [LedgerCategory]
    @Query(sort: \LedgerSubcategory.sortOrder)
    private var subcategories: [LedgerSubcategory]

    let slice: ExpenseCategorySlice
    let selectedMonth: Date

    private let calendar = Calendar.autoupdatingCurrent

    private var selectedMonthInterval: DateInterval {
        CalendarIntervals.month(containing: selectedMonth, calendar: calendar)
            ?? DateInterval(start: .distantPast, end: .distantFuture)
    }

    var body: some View {
        TransactionQueryView(interval: selectedMonthInterval) { transactions in
            content(transactions: transactions)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(slice.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(transactions: [LedgerTransaction]) -> some View {
        let monthlySummary = StatisticsService.monthlySummary(
            for: transactions,
            containing: selectedMonth,
            calendar: calendar
        )
        let details = ReportService.detailItems(
            for: slice,
            transactions: transactions,
            categories: categories,
            subcategories: subcategories,
            inMonthContaining: selectedMonth,
            calendar: calendar
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryModule(monthlyExpenseInCents: monthlySummary.expenseInCents)
                    .insetGroupedModule()

                detailsModule(details)
                    .insetGroupedModule()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func summaryModule(monthlyExpenseInCents: Int64) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(MoneyAmount.formatted(cents: slice.amountInCents))
                .font(.largeTitle.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(
                "占本月支出 \(percentageText(slice.percentage(of: monthlyExpenseInCents)))"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func detailsModule(_ details: [ReportDetailItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类明细")
                .font(.title2.bold())

            if details.isEmpty {
                ContentUnavailableView(
                    "暂无分类明细",
                    systemImage: "list.bullet",
                    description: Text("当前分类在本月没有可展示的支出。")
                )
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 20)
            } else {
                ForEach(details) { item in
                    detailRow(item)

                    if item.id != details.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func detailRow(_ item: ReportDetailItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.name)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(MoneyAmount.formatted(cents: item.amountInCents))
                .monospacedDigit()
                .lineLimit(1)

            Text(percentageText(item.percentage(of: slice.amountInCents)))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
        }
        .font(.body)
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var monthTitle: String {
        selectedMonth.formatted(
            Date.FormatStyle()
                .year()
                .month(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    private func percentageText(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}

