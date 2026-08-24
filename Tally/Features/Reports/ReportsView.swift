//
//  ReportsView.swift
//  Tally
//

import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    private enum ReportMode: String, CaseIterable, Identifiable {
        case report = "报表"
        case calendar = "日历"

        var id: Self { self }
    }

    private struct RenderContext {
        let snapshot: MonthlyReportSnapshot
        let categoryColorsByID: [UUID: LedgerCategoryColor]
    }

    private struct CategoryDetailDestination: Hashable {
        let slice: ExpenseCategorySlice
        let month: Date
    }

    @Query(sort: \LedgerCategory.sortOrder)
    private var categories: [LedgerCategory]

    @State private var mode: ReportMode = .report
    @State private var selectedMonth = Date.now
    @State private var categoryDetailDestination: CategoryDetailDestination?
    @State private var isPresentingMonthPicker = false

    private let calendar = Calendar.autoupdatingCurrent

    private func makeRenderContext(
        transactions: [LedgerTransaction]
    ) -> RenderContext {
        let snapshot = ReportService.monthlySnapshot(
            for: transactions,
            categories: categories,
            inMonthContaining: selectedMonth,
            calendar: calendar
        )
        return RenderContext(
            snapshot: snapshot,
            categoryColorsByID: Dictionary(
                uniqueKeysWithValues: categories.map {
                    (
                        $0.id,
                        LedgerCategoryColor.resolve(for: $0)
                    )
                }
            )
        )
    }

    private var selectedMonthInterval: DateInterval {
        CalendarIntervals.month(containing: selectedMonth, calendar: calendar)
            ?? DateInterval(start: .distantPast, end: .distantFuture)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("报表视图", selection: $mode) {
                ForEach(ReportMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch mode {
            case .report:
                TransactionQueryView(interval: selectedMonthInterval) { transactions in
                    reportContent(transactions: transactions)
                }
            case .calendar:
                CalendarReportView(selectedMonth: $selectedMonth)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(mode.rawValue)
        .navigationDestination(item: $categoryDetailDestination) { destination in
            ReportCategoryDetailView(
                slice: destination.slice,
                selectedMonth: destination.month
            )
        }
        .sheet(isPresented: $isPresentingMonthPicker) {
            MonthPickerView(selectedDate: selectedMonth, calendar: calendar) { month in
                selectedMonth = month
            }
        }
    }

    private func reportContent(transactions: [LedgerTransaction]) -> some View {
        let context = makeRenderContext(transactions: transactions)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthSummary(context.snapshot.summary)
                    .insetGroupedModule()

                expenseCategorySection(context)
                    .insetGroupedModule()

                dailyTrendSection(context)
                    .insetGroupedModule()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func monthSummary(_ summary: MonthlyLedgerSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                isPresentingMonthPicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(monthTitle)
                        .font(.title2.bold())
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("选择要查看的年份和月份")

            HStack(spacing: 24) {
                summaryItem(title: "月支出", cents: summary.expenseInCents)
                summaryItem(title: "月收入", cents: summary.incomeInCents)
            }
        }
    }

    private func expenseCategorySection(_ context: RenderContext) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("支出分类")
                .font(.title2.bold())

            if context.snapshot.categorySlices.isEmpty {
                ContentUnavailableView(
                    "暂无支出数据",
                    systemImage: "chart.pie",
                    description: Text("本月记录支出后会显示分类占比。")
                )
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 24)
            } else {
                donutChart(context)
                categoryLegend(context)
            }
        }
    }

    private func donutChart(_ context: RenderContext) -> some View {
        ZStack {
            Chart(context.snapshot.categorySlices) { slice in
                SectorMark(
                    angle: .value("金额", Double(slice.amountInCents)),
                    innerRadius: .ratio(0.64),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(color(for: slice, in: context))
                .accessibilityLabel(slice.name)
                .accessibilityValue(
                    "\(MoneyAmount.formatted(cents: slice.amountInCents))，\(percentageText(for: slice, totalInCents: context.snapshot.summary.expenseInCents))"
                )
            }
            .chartLegend(.hidden)
            .chartGesture { proxy in
                SpatialTapGesture().onEnded { value in
                    let radius = min(proxy.plotSize.width, proxy.plotSize.height) / 2
                    let center = CGPoint(
                        x: proxy.plotSize.width / 2,
                        y: proxy.plotSize.height / 2
                    )
                    let distance = hypot(
                        value.location.x - center.x,
                        value.location.y - center.y
                    )
                    guard distance >= radius * 0.58, distance <= radius else { return }

                    let angle = proxy.angle(at: value.location)
                    guard let accumulatedValue: Double = proxy.value(atAngle: angle),
                          let slice = ReportService.categorySlice(
                            at: accumulatedValue,
                            in: context.snapshot.categorySlices
                          )
                    else {
                        return
                    }
                    showDetails(for: slice)
                }
            }
            .frame(height: 260)
            .accessibilityLabel("本月支出分类占比")

            VStack(spacing: 4) {
                Text("本月支出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(
                    MoneyAmount.formatted(
                        cents: context.snapshot.summary.expenseInCents
                    )
                )
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.75)

            }
            .frame(width: 112)
            .accessibilityElement(children: .combine)
        }
    }

    private func categoryLegend(_ context: RenderContext) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(context.snapshot.categorySlices) { slice in
                Button {
                    showDetails(for: slice)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color(for: slice, in: context))
                            .frame(width: 9, height: 9)

                        Text(slice.name)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text(
                            percentageText(
                                for: slice,
                                totalInCents: context.snapshot.summary.expenseInCents
                            )
                        )
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.clear)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(slice.name)，\(percentageText(for: slice, totalInCents: context.snapshot.summary.expenseInCents))"
                )
                .accessibilityHint("查看分类明细")
            }
        }
    }

    private func dailyTrendSection(_ context: RenderContext) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("每日支出趋势")
                .font(.title2.bold())

            if context.snapshot.summary.expenseInCents == 0 {
                ContentUnavailableView(
                    "暂无趋势数据",
                    systemImage: "chart.xyaxis.line",
                    description: Text("本月支出会按自然日显示在这里。")
                )
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 24)
            } else {
                Chart(context.snapshot.dailyExpensePoints) { point in
                    AreaMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("支出", point.amountInYuan)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("支出", point.amountInYuan)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if point.amountInCents > 0 {
                        PointMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("支出", point.amountInYuan)
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(20)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(
                                    amount,
                                    format: .currency(code: "CNY")
                                        .precision(.fractionLength(0))
                                )
                            }
                        }
                    }
                }
                .frame(height: 220)
                .accessibilityLabel("本月每日支出趋势")
                .accessibilityValue(
                    trendAccessibilitySummary(for: context.snapshot.dailyExpensePoints)
                )

                Text(trendAccessibilitySummary(for: context.snapshot.dailyExpensePoints))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryItem(title: String, cents: Int64) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MoneyAmount.formatted(cents: cents))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func percentageText(
        for slice: ExpenseCategorySlice,
        totalInCents: Int64
    ) -> String {
        slice.percentage(of: totalInCents)
            .formatted(.percent.precision(.fractionLength(1)))
    }

    private func color(
        for slice: ExpenseCategorySlice,
        in context: RenderContext
    ) -> Color {
        guard !slice.isMerged, let categoryID = slice.categoryIDs.first else {
            return LedgerCategoryColor.gray.color
        }
        return context.categoryColorsByID[categoryID]?.color
            ?? LedgerCategoryColor.gray.color
    }

    private func showDetails(for slice: ExpenseCategorySlice) {
        categoryDetailDestination = CategoryDetailDestination(
            slice: slice,
            month: selectedMonth
        )
    }

    private func trendAccessibilitySummary(for points: [DailyExpensePoint]) -> String {
        let spendingDays = points.filter { $0.amountInCents > 0 }
        guard let highest = spendingDays.max(by: { $0.amountInCents < $1.amountInCents }) else {
            return "本月暂无支出"
        }

        let date = highest.date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
        return "本月有\(spendingDays.count)天产生支出，最高为\(date)的\(MoneyAmount.formatted(cents: highest.amountInCents))"
    }
}

#Preview {
    NavigationStack {
        ReportsView()
    }
    .modelContainer(
        for: [LedgerTransaction.self, LedgerCategory.self, LedgerSubcategory.self],
        inMemory: true
    )
}
