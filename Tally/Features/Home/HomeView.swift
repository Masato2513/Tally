//
//  HomeView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct HomeView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let transactions: [LedgerTransaction]

        var id: Date { date }
    }

    private struct ContentSnapshot {
        let monthlySummary: MonthlyLedgerSummary
        let recentDayGroups: [DayGroup]
        let categoryLookup: LedgerCategoryLookup
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerCategory.sortOrder)
    private var categories: [LedgerCategory]
    @Query(sort: \LedgerSubcategory.sortOrder)
    private var subcategories: [LedgerSubcategory]
    @State private var isPresentingRecord = false
    @State private var editingTransaction: LedgerTransaction?
    @State private var pendingDeleteTransaction: LedgerTransaction?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteError = false

    private let calendar = Calendar.autoupdatingCurrent

    private func contentSnapshot(for transactions: [LedgerTransaction]) -> ContentSnapshot {
        let monthlySummary = StatisticsService.monthlySummary(
            for: transactions,
            calendar: calendar
        )
        let recentTransactions = StatisticsService.transactionsWithinLastDays(
            3,
            from: transactions,
            calendar: calendar
        )
        let groupedTransactions = Dictionary(grouping: recentTransactions) {
            calendar.startOfDay(for: $0.date)
        }

        let recentDayGroups = groupedTransactions
            .map { DayGroup(date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }

        return ContentSnapshot(
            monthlySummary: monthlySummary,
            recentDayGroups: recentDayGroups,
            categoryLookup: LedgerCategoryLookup(
                categories: categories,
                subcategories: subcategories
            )
        )
    }

    private var defaultExpenseCategoryID: UUID? {
        RecordCategorySelectionService.defaultExpenseCategoryID(in: categories)
    }

    private var relevantTransactionInterval: DateInterval {
        CalendarIntervals.monthAndRecentDays(3, containing: .now, calendar: calendar)
            ?? DateInterval(start: .distantPast, end: .distantFuture)
    }

    var body: some View {
        TransactionQueryView(interval: relevantTransactionInterval) { transactions in
            content(transactions: transactions)
        }
        .navigationTitle("首页")
        .sheet(isPresented: $isPresentingRecord) {
            RecordView(initialCategoryID: defaultExpenseCategoryID)
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

    private func content(transactions: [LedgerTransaction]) -> some View {
        let snapshot = contentSnapshot(for: transactions)

        return List {
            Section {
                monthlyOverview(summary: snapshot.monthlySummary)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
            }

            if snapshot.recentDayGroups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "近三日暂无账单",
                        systemImage: "clock",
                        description: Text("点击“+ 记账”开始记录。")
                    )
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
                    .listRowSeparator(.hidden)
                } header: {
                    recentTransactionsTitle
                }
            } else {
                ForEach(Array(snapshot.recentDayGroups.enumerated()), id: \.element.id) { index, group in
                    Section {
                        ForEach(group.transactions) { transaction in
                            transactionRow(transaction, categoryLookup: snapshot.categoryLookup)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 10) {
                            if index == 0 {
                                recentTransactionsTitle
                            }

                            TransactionDaySectionHeader(
                                date: group.date,
                                expenseInCents: StatisticsService.expenseTotal(
                                    for: group.transactions
                                ),
                                calendar: calendar
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
    }

    private func monthlyOverview(summary: MonthlyLedgerSummary) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("本月支出")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(MoneyAmount.formatted(cents: summary.expenseInCents))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel(
                        "本月支出，\(MoneyAmount.formatted(cents: summary.expenseInCents))"
                    )
            }

            Button {
                isPresentingRecord = true
            } label: {
                Text("+ 记账")
                    .frame(alignment: .center)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)

            HStack(alignment: .top, spacing: 20) {
                summaryItem(
                    title: "本月收入",
                    cents: summary.incomeInCents
                )

                Divider()
                    .frame(height: 42)

                summaryItem(
                    title: "月结余",
                    cents: summary.balanceInCents
                )
            }
        }
    }

    private var recentTransactionsTitle: some View {
        Text("近三日账单")
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    private func summaryItem(title: String, cents: Int64) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(MoneyAmount.formatted(cents: cents))
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func transactionRow(
        _ transaction: LedgerTransaction,
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        let display = categoryLookup.display(for: transaction, showsDate: false)

        return Button {
            editingTransaction = transaction
        } label: {
            BillsTransactionRow(
                categoryTitle: display.categoryTitle,
                symbolName: display.symbolName,
                categoryColor: display.categoryColor,
                dateText: display.dateText,
                noteText: display.noteText,
                amountText: display.amountText
            )
            .equatable()
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("删除", systemImage: "trash") {
                pendingDeleteTransaction = transaction
                isShowingDeleteConfirmation = true
            }
            .tint(.red)
        }
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
        HomeView()
    }
    .modelContainer(
        for: [LedgerTransaction.self, LedgerCategory.self, LedgerSubcategory.self],
        inMemory: true
    )
}
