//
//  CalendarReportView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct CalendarReportView<Header: View>: View {
    private struct CalendarSlot: Identifiable {
        let id: Int
        let summary: CalendarDaySummary?
    }

    @Binding var selectedMonth: Date
    let transactionType: LedgerTransactionType
    @State private var isPresentingMonthPicker = false
    @State private var selectedDay: CalendarDaySummary?

    private let header: Header
    private let calendar = Calendar.autoupdatingCurrent
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    init(
        selectedMonth: Binding<Date>,
        transactionType: LedgerTransactionType,
        @ViewBuilder header: () -> Header
    ) {
        _selectedMonth = selectedMonth
        self.transactionType = transactionType
        self.header = header()
    }

    private func slots(for daySummaries: [CalendarDaySummary]) -> [CalendarSlot] {
        let blankCount = CalendarReportService.leadingBlankCount(
            forMonthContaining: selectedMonth,
            calendar: calendar
        )
        let blankSlots = (0..<blankCount).map { CalendarSlot(id: $0, summary: nil) }
        let daySlots = daySummaries.enumerated().map { offset, summary in
            CalendarSlot(id: blankCount + offset, summary: summary)
        }
        return blankSlots + daySlots
    }

    private var weekdaySymbols: [String] {
        CalendarReportService.orderedVeryShortWeekdaySymbols(calendar: calendar)
    }

    private var selectedMonthInterval: DateInterval {
        CalendarIntervals.month(containing: selectedMonth, calendar: calendar)
            ?? DateInterval(start: .distantPast, end: .distantFuture)
    }

    var body: some View {
        TransactionQueryView(interval: selectedMonthInterval) { transactions in
            content(transactions: transactions)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $isPresentingMonthPicker) {
            MonthPickerView(selectedDate: selectedMonth, calendar: calendar) { month in
                selectedMonth = month
            }
        }
        .sheet(item: $selectedDay) { day in
            DailyTransactionsView(
                date: day.date,
                transactionType: transactionType
            )
        }
    }

    private func content(transactions: [CurrentLedgerTransaction]) -> some View {
        let snapshot = CalendarReportService.monthSnapshot(
            for: transactions,
            inMonthContaining: selectedMonth,
            transactionType: transactionType,
            calendar: calendar
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    monthNavigation

                    Divider()

                    weekdayHeader
                    calendarGrid(snapshot: snapshot)
                }
                .insetGroupedModule(contentPadding: 12)

                VStack(alignment: .leading, spacing: 14) {
                    intensityLegend

                    Divider()

                    HStack {
                        Text("本月\(transactionType.title)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(MoneyAmount.formatted(cents: snapshot.monthlyAmountInCents))
                            .font(.headline)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                }
                .insetGroupedModule()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var monthNavigation: some View {
        HStack {
            Button("上个月", systemImage: "chevron.left") {
                moveMonth(by: -1)
            }
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)

            Spacer()

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
            .accessibilityHint("选择年份和月份")

            Spacer()

            Button("下个月", systemImage: "chevron.right") {
                moveMonth(by: 1)
            }
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    private func calendarGrid(snapshot: CalendarMonthSnapshot) -> some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(slots(for: snapshot.daySummaries)) { slot in
                if let summary = slot.summary {
                    dayButton(
                        summary,
                        maximumDailyAmountInCents: snapshot.maximumDailyAmountInCents
                    )
                } else {
                    Color.clear
                        .frame(minHeight: 62)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func dayButton(
        _ summary: CalendarDaySummary,
        maximumDailyAmountInCents: Int64
    ) -> some View {
        let intensity = CalendarReportService.relativeIntensity(
            amountInCents: summary.amountInCents,
            maximumInCents: maximumDailyAmountInCents
        )
        let fillOpacity = summary.amountInCents > 0 ? 0.10 + 0.34 * intensity.squareRoot() : 0
        let isToday = calendar.isDateInToday(summary.date)
        let reportColor = LedgerTransactionStyle.reportColor(for: transactionType)

        return Button {
            selectedDay = summary
        } label: {
            VStack(spacing: 5) {
                Text(calendar.component(.day, from: summary.date), format: .number)
                    .font(.subheadline.weight(isToday ? .bold : .medium))

                if summary.amountInCents > 0 {
                    Text(compactAmount(summary.amountInCents))
                        .font(.caption2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                } else {
                    Text(" ")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .foregroundStyle(.primary)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(reportColor.opacity(fillOpacity))
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(reportColor, lineWidth: 1.5)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(summary))
        .accessibilityHint("查看当天账单")
    }

    private var intensityLegend: some View {
        let reportColor = LedgerTransactionStyle.reportColor(for: transactionType)

        return HStack(spacing: 8) {
            ForEach([0.12, 0.26, 0.44], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(reportColor.opacity(opacity))
                    .frame(width: 18, height: 12)
            }

            Text("颜色越深，\(transactionType.title)越高")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private func moveMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: selectedMonth) else {
            return
        }
        selectedMonth = CalendarIntervals.month(containing: month, calendar: calendar)?.start ?? month
    }

    private func compactAmount(_ cents: Int64) -> String {
        let amount = Double(cents) / 100
        let formatted = amount.formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
                .locale(Locale(identifier: "zh_CN"))
        )
        let sign = transactionType == .expense ? "-" : "+"
        return "\(sign)¥\(formatted)"
    }

    private func dayAccessibilityLabel(_ summary: CalendarDaySummary) -> String {
        let date = summary.date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .day()
                .weekday(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
        guard summary.amountInCents > 0 else {
            return "\(date)，无\(transactionType.title)"
        }
        return "\(date)，\(transactionType.title)\(MoneyAmount.formatted(cents: summary.amountInCents))"
    }
}
