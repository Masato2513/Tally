//
//  DailyTransactionsView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct DailyTransactionsView: View {
    private struct ContentSnapshot {
        let transactions: [LedgerTransaction]
        let expenseInCents: Int64
        let categoryLookup: LedgerCategoryLookup
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerCategory.sortOrder)
    private var categories: [LedgerCategory]
    @Query(sort: \LedgerSubcategory.sortOrder)
    private var subcategories: [LedgerSubcategory]

    let date: Date

    @State private var isPresentingNewRecord = false
    @State private var editingTransaction: LedgerTransaction?
    @State private var pendingDeleteTransaction: LedgerTransaction?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteError = false

    private let calendar = Calendar.autoupdatingCurrent

    private func contentSnapshot(for transactions: [LedgerTransaction]) -> ContentSnapshot {
        let dayTransactions = CalendarReportService.transactions(
            onDayContaining: date,
            from: transactions,
            calendar: calendar
        )
        return ContentSnapshot(
            transactions: dayTransactions,
            expenseInCents: StatisticsService.expenseTotal(for: dayTransactions),
            categoryLookup: LedgerCategoryLookup(
                categories: categories,
                subcategories: subcategories
            )
        )
    }

    private var defaultExpenseCategoryID: UUID? {
        RecordCategorySelectionService.defaultExpenseCategoryID(in: categories)
    }

    private var selectedDayInterval: DateInterval {
        CalendarIntervals.day(containing: date, calendar: calendar)
            ?? DateInterval(start: .distantPast, end: .distantFuture)
    }

    var body: some View {
        TransactionQueryView(interval: selectedDayInterval) { transactions in
            content(transactions: transactions)
        }
    }

    private func content(transactions: [LedgerTransaction]) -> some View {
        let snapshot = contentSnapshot(for: transactions)

        return NavigationStack {
            List {
                Section {
                    HStack {
                        Text("当日支出")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(MoneyAmount.formatted(cents: snapshot.expenseInCents))
                            .font(.headline)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                }

                if snapshot.transactions.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "当天暂无账单",
                            systemImage: "calendar.badge.minus",
                            description: Text("可以直接为这一天记录一笔。")
                        )
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section("账单") {
                        ForEach(snapshot.transactions) { transaction in
                            transactionRow(
                                transaction,
                                categoryLookup: snapshot.categoryLookup
                            )
                        }
                    }
                }
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("记一笔", systemImage: "plus") {
                        isPresentingNewRecord = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .sheet(isPresented: $isPresentingNewRecord) {
                RecordView(
                    initialDate: CalendarReportService.recordDate(
                        on: date,
                        calendar: calendar
                    ),
                    initialCategoryID: defaultExpenseCategoryID
                )
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
        .presentationDetents([.medium, .large])
    }

    private func transactionRow(
        _ transaction: LedgerTransaction,
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        let display = categoryLookup.display(for: transaction, showsDate: true)

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

    private var dayTitle: String {
        date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .day()
                .weekday(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}
