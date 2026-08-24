//
//  ReportsView.swift
//  Tally
//

import Charts
import SwiftData
import SwiftUI
import UIKit

/// 仅当手势从已选中的图表数据点附近开始时接管拖动。
/// 一旦开始，不再限制移动方向；松手后外层 ScrollView 会恢复正常响应。
private struct SelectedChartPointPanGesture: UIGestureRecognizerRepresentable {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let converter: UIGestureRecognizerRepresentableCoordinateSpaceConverter
        var shouldBegin: (CGPoint) -> Bool
        var onChanged: (CGPoint) -> Void

        init(
            converter: UIGestureRecognizerRepresentableCoordinateSpaceConverter,
            shouldBegin: @escaping (CGPoint) -> Bool,
            onChanged: @escaping (CGPoint) -> Void
        ) {
            self.converter = converter
            self.shouldBegin = shouldBegin
            self.onChanged = onChanged
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer is UIPanGestureRecognizer else {
                return false
            }
            let location = converter.localLocation
            let translation = converter.localTranslation ?? .zero
            let initialLocation = CGPoint(
                x: location.x - translation.x,
                y: location.y - translation.y
            )
            return shouldBegin(initialLocation)
        }
    }

    let shouldBegin: (CGPoint) -> Bool
    let onChanged: (CGPoint) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(
            converter: converter,
            shouldBegin: shouldBegin,
            onChanged: onChanged
        )
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.delegate = context.coordinator
        gesture.maximumNumberOfTouches = 1
        gesture.cancelsTouchesInView = false
        return gesture
    }

    func updateUIGestureRecognizer(
        _ recognizer: UIPanGestureRecognizer,
        context: Context
    ) {
        context.coordinator.shouldBegin = shouldBegin
        context.coordinator.onChanged = onChanged
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer,
        context: Context
    ) {
        guard recognizer.state == .began || recognizer.state == .changed else {
            return
        }
        context.coordinator.onChanged(context.converter.localLocation)
    }
}

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

    private struct CategoryDetailPresentation: Identifiable {
        let slice: ExpenseCategorySlice
        let month: Date

        var id: String {
            "\(slice.id):\(month.timeIntervalSinceReferenceDate)"
        }
    }

    @Query(sort: \CurrentLedgerCategory.sortOrder)
    private var categories: [CurrentLedgerCategory]

    @State private var mode: ReportMode = .report
    @State private var selectedMonth = Date.now
    @State private var categoryDetailPresentation: CategoryDetailPresentation?
    @State private var isPresentingMonthPicker = false
    @State private var selectedTrendDate: Date?
    @State private var dailyTrendChartFrame = CGRect.null

    private let calendar = Calendar.autoupdatingCurrent
    private static let reportContentCoordinateSpace = "reportContent"

    private func makeRenderContext(
        transactions: [CurrentLedgerTransaction]
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
        Group {
            switch mode {
            case .report:
                TransactionQueryView(interval: selectedMonthInterval) { transactions in
                    reportContent(transactions: transactions)
                }
            case .calendar:
                CalendarReportView(selectedMonth: $selectedMonth) {
                    reportModePicker
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(mode.rawValue)
        .sheet(item: $categoryDetailPresentation) { presentation in
            ReportCategoryDetailView(
                slice: presentation.slice,
                selectedMonth: presentation.month
            )
        }
        .sheet(isPresented: $isPresentingMonthPicker) {
            MonthPickerView(selectedDate: selectedMonth, calendar: calendar) { month in
                selectedMonth = month
            }
        }
        .onChange(of: selectedMonth) {
            selectedTrendDate = nil
        }
        .onChange(of: mode) {
            if mode != .report {
                selectedTrendDate = nil
            }
        }
    }

    private func reportContent(transactions: [CurrentLedgerTransaction]) -> some View {
        let context = makeRenderContext(transactions: transactions)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                reportModePicker

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
        .coordinateSpace(name: Self.reportContentCoordinateSpace)
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                guard selectedTrendDate != nil,
                      !dailyTrendChartFrame.contains(value.location)
                else {
                    return
                }
                selectedTrendDate = nil
            }
        )
    }

    private var reportModePicker: some View {
        Picker("报表视图", selection: $mode) {
            ForEach(ReportMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
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
        let points = context.snapshot.dailyExpensePoints
        let selectedPoint = selectedTrendDate.flatMap { selectedDate in
            ReportService.nearestDailyExpensePoint(to: selectedDate, in: points)
        }
        let axisDates = points.indices.compactMap { index in
            index.isMultiple(of: 7) ? points[index].date : nil
        }
        let highestAmount = points.map(\.amountInYuan).max() ?? 0
        let yUpperBound = max(highestAmount * 1.12, 1)

        return VStack(alignment: .leading, spacing: 16) {
            Text("每日支出趋势")
                .font(.title2.bold())

            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("支出", point.amountInYuan)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [
                                Color.accentColor.opacity(0.22),
                                Color.accentColor.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("支出", point.amountInYuan)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                if let selectedPoint {
                    RuleMark(
                        x: .value("选中日期", selectedPoint.date, unit: .day)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("选中日期", selectedPoint.date, unit: .day),
                        y: .value("当日支出", selectedPoint.amountInYuan)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(64)
                }
            }
            .chartXAxis {
                AxisMarks(values: axisDates) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text("\(calendar.component(.day, from: date))日")
                        }
                    }
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
            .chartYScale(domain: 0...yUpperBound)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(.rect)
                        .gesture(
                            SelectedChartPointPanGesture(
                                shouldBegin: { location in
                                    canBeginTrendDrag(
                                        at: location,
                                        selectedPoint: selectedPoint,
                                        proxy: proxy,
                                        geometry: geometry
                                    )
                                },
                                onChanged: { location in
                                    updateTrendSelection(
                                        at: location,
                                        proxy: proxy,
                                        geometry: geometry,
                                        points: points
                                    )
                                }
                            )
                        )
                        .simultaneousGesture(
                            SpatialTapGesture().onEnded { value in
                                updateTrendSelection(
                                    at: value.location,
                                    proxy: proxy,
                                    geometry: geometry,
                                    points: points
                                )
                            }
                        )
                }
            }
            .chartOverlay(alignment: .top) { _ in
                if let selectedPoint {
                    Text(trendSelectionText(for: selectedPoint))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 220)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(Self.reportContentCoordinateSpace))
            } action: { newFrame in
                dailyTrendChartFrame = newFrame
            }
            .sensoryFeedback(
                .selection,
                trigger: selectedTrendDate,
                condition: { oldValue, newValue in
                    oldValue != nil && newValue != nil && oldValue != newValue
                }
            )
            .accessibilityLabel("本月每日支出趋势")
            .accessibilityValue(
                selectedPoint.map(trendSelectionText(for:))
                    ?? trendAccessibilitySummary(for: points)
            )

            Text(trendAccessibilitySummary(for: points))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func updateTrendSelection(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        points: [DailyExpensePoint]
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else { return }

        let plotX = location.x - plotFrame.minX
        guard let candidateDate: Date = proxy.value(atX: plotX) else { return }
        let snappedDate = ReportService.nearestDailyExpensePoint(
            to: candidateDate,
            in: points
        )?.date
        guard snappedDate != selectedTrendDate else { return }
        selectedTrendDate = snappedDate
    }

    private func canBeginTrendDrag(
        at location: CGPoint,
        selectedPoint: DailyExpensePoint?,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> Bool {
        guard let selectedPoint,
              let plotFrameAnchor = proxy.plotFrame,
              let pointX = proxy.position(forX: selectedPoint.date),
              let pointY = proxy.position(forY: selectedPoint.amountInYuan)
        else {
            return false
        }

        let plotFrame = geometry[plotFrameAnchor]
        let pointLocation = CGPoint(
            x: plotFrame.minX + pointX,
            y: plotFrame.minY + pointY
        )
        let touchTargetRadius: CGFloat = 28
        return hypot(
            location.x - pointLocation.x,
            location.y - pointLocation.y
        ) <= touchTargetRadius
    }

    private func trendSelectionText(for point: DailyExpensePoint) -> String {
        let date = point.date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
        return "\(date) \(MoneyAmount.formatted(cents: point.amountInCents))"
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
        categoryDetailPresentation = CategoryDetailPresentation(
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
        for: [CurrentLedgerTransaction.self, CurrentLedgerCategory.self, CurrentLedgerSubcategory.self],
        inMemory: true
    )
}
