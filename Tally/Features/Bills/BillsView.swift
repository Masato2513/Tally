//
//  BillsView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct BillsView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let transactions: [CurrentLedgerTransaction]

        var id: Date { date }
    }

    private struct ContentSnapshot {
        let monthlyTransactions: [CurrentLedgerTransaction]
        let monthlySummary: MonthlyLedgerSummary
        let dayGroups: [DayGroup]
        let categoryLookup: LedgerCategoryLookup
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CurrentLedgerCategory.sortOrder)
    private var categories: [CurrentLedgerCategory]
    @Query(sort: \CurrentLedgerSubcategory.sortOrder)
    private var subcategories: [CurrentLedgerSubcategory]

    @State private var selectedMonth = Date.now
    @State private var sortOrder: BillsSortOrder = .time
    @State private var isPresentingMonthPicker = false
    @State private var editingTransaction: CurrentLedgerTransaction?
    @State private var pendingDeleteTransaction: CurrentLedgerTransaction?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteError = false

    private let calendar = Calendar.autoupdatingCurrent

    private func contentSnapshot(for transactions: [CurrentLedgerTransaction]) -> ContentSnapshot {
        let monthlyTransactions = BillsService.transactions(
            inMonthContaining: selectedMonth,
            from: transactions,
            sortedBy: sortOrder,
            calendar: calendar
        )
        let monthlySummary = StatisticsService.monthlySummary(
            for: monthlyTransactions,
            containing: selectedMonth,
            calendar: calendar
        )
        let grouped = Dictionary(grouping: monthlyTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        let dayGroups = grouped
            .map { DayGroup(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }

        return ContentSnapshot(
            monthlyTransactions: monthlyTransactions,
            monthlySummary: monthlySummary,
            dayGroups: dayGroups,
            categoryLookup: LedgerCategoryLookup(
                categories: categories,
                subcategories: subcategories
            )
        )
    }

    private var selectedMonthInterval: DateInterval {
        CalendarIntervals.month(containing: selectedMonth, calendar: calendar)
            ?? DateInterval(start: .distantPast, end: .distantFuture)
    }

    var body: some View {
        TransactionQueryView(interval: selectedMonthInterval) { transactions in
            content(transactions: transactions)
        }
        .navigationTitle("账单")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("排序方式", selection: $sortOrder) {
                        ForEach(BillsSortOrder.allCases) { order in
                            Label(order.title, systemImage: order.systemImage)
                                .tag(order)
                        }
                    }
                } label: {
                    Label("排序", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityHint("当前为\(sortOrder.title)")
            }
        }
        .sheet(isPresented: $isPresentingMonthPicker) {
            MonthPickerView(selectedDate: selectedMonth, calendar: calendar) { month in
                selectedMonth = month
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            RecordView(transaction: transaction)
        }
        .alert("", isPresented: $isShowingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                pendingDeleteTransaction = nil
            }
            Button("删除", role: .destructive, action: deletePendingTransaction)
        } message: {
            Text("删除后无法恢复，确定要删除这笔账单吗？")
        }
        .alert("无法删除账单", isPresented: $isShowingDeleteError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("本地数据库写入失败，请稍后重试。")
        }
    }

    private func content(transactions: [CurrentLedgerTransaction]) -> some View {
        let snapshot = contentSnapshot(for: transactions)

        return List {
            Section {
                monthOverview(summary: snapshot.monthlySummary)
            }

            if snapshot.monthlyTransactions.isEmpty {
                Section {
                    ContentUnavailableView(
                        "本月暂无账单",
                        systemImage: "calendar.badge.minus",
                        description: Text("切换月份，或从首页记录一笔新账单。")
                    )
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowSeparator(.hidden)
                }
            } else if sortOrder == .time {
                timeSortedSections(
                    groups: snapshot.dayGroups,
                    categoryLookup: snapshot.categoryLookup
                )
            } else {
                amountSortedSection(
                    transactions: snapshot.monthlyTransactions,
                    categoryLookup: snapshot.categoryLookup
                )
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
    }

    private func monthOverview(summary: MonthlyLedgerSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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

            HStack(spacing: 20) {
                summaryItem(title: "支出", cents: summary.expenseInCents)
                summaryItem(title: "收入", cents: summary.incomeInCents)
                summaryItem(title: "结余", cents: summary.balanceInCents)
            }
        }
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func timeSortedSections(
        groups: [DayGroup],
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        ForEach(groups) { group in
            Section {
                ForEach(group.transactions) { transaction in
                    transactionRow(
                        transaction,
                        showsDate: false,
                        categoryLookup: categoryLookup
                    )
                }
            } header: {
                TransactionDaySectionHeader(
                    date: group.date,
                    expenseInCents: StatisticsService.expenseTotal(for: group.transactions),
                    calendar: calendar
                )
            }
        }
    }

    private func amountSortedSection(
        transactions: [CurrentLedgerTransaction],
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        Section("按金额从高到低") {
            ForEach(transactions) { transaction in
                transactionRow(
                    transaction,
                    showsDate: true,
                    categoryLookup: categoryLookup
                )
            }
        }
    }

    private func summaryItem(title: String, cents: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(MoneyAmount.formatted(cents: cents))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func transactionRow(
        _ transaction: CurrentLedgerTransaction,
        showsDate: Bool,
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        let display = categoryLookup.display(for: transaction, showsDate: showsDate)

        return BillsTransactionRow(
            categoryTitle: display.categoryTitle,
            symbolName: display.symbolName,
            categoryColor: display.categoryColor,
            secondaryText: display.secondaryText,
            amountText: display.amountText
        )
        .equatable()
        .onTapGesture {
            editingTransaction = transaction
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            editingTransaction = transaction
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("删除", systemImage: "trash") {
                pendingDeleteTransaction = transaction
                isShowingDeleteConfirmation = true
            }
            .tint(.red)
        }
    }

    private var monthTitle: String {
        selectedMonth.formatted(
            Date.FormatStyle()
                .year()
                .month(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    private func deletePendingTransaction() {
        guard let transaction = pendingDeleteTransaction else { return }
        pendingDeleteTransaction = nil
        modelContext.delete(transaction)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            isShowingDeleteError = true
        }
    }
}

#Preview {
    NavigationStack {
        BillsView()
    }
    .modelContainer(
        for: [CurrentLedgerTransaction.self, CurrentLedgerCategory.self, CurrentLedgerSubcategory.self],
        inMemory: true
    )
}
