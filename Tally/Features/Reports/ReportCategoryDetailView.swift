//
//  ReportCategoryDetailView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct ReportCategoryDetailView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let transactions: [LedgerTransaction]

        var id: Date { date }
    }

    private struct ContentSnapshot {
        let monthlyExpenseInCents: Int64
        let categoryExpenseInCents: Int64
        let details: [ReportDetailItem]
        let dayGroups: [DayGroup]
        let categoryLookup: LedgerCategoryLookup
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerCategory.sortOrder)
    private var categories: [LedgerCategory]
    @Query(sort: \LedgerSubcategory.sortOrder)
    private var subcategories: [LedgerSubcategory]

    let slice: ExpenseCategorySlice
    let selectedMonth: Date

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var editingTransaction: LedgerTransaction?
    @State private var pendingDeleteTransaction: LedgerTransaction?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteError = false

    private let calendar = Calendar.autoupdatingCurrent

    private var selectedMonthInterval: DateInterval {
        CalendarIntervals.month(containing: selectedMonth, calendar: calendar)
            ?? DateInterval(start: .distantPast, end: .distantFuture)
    }

    var body: some View {
        TransactionQueryView(interval: selectedMonthInterval) { transactions in
            content(transactions: transactions)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private func contentSnapshot(
        for transactions: [LedgerTransaction]
    ) -> ContentSnapshot {
        let categoryIDs = Set(slice.categoryIDs)
        let categoryTransactions = transactions
            .filter {
                $0.type == .expense && categoryIDs.contains($0.categoryID)
            }
            .sorted { $0.date > $1.date }
        let grouped = Dictionary(grouping: categoryTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        let dayGroups = grouped
            .map { DayGroup(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }

        return ContentSnapshot(
            monthlyExpenseInCents: StatisticsService.monthlySummary(
                for: transactions,
                containing: selectedMonth,
                calendar: calendar
            ).expenseInCents,
            categoryExpenseInCents: StatisticsService.expenseTotal(
                for: categoryTransactions
            ),
            details: ReportService.detailItems(
                for: slice,
                transactions: transactions,
                categories: categories,
                subcategories: subcategories,
                inMonthContaining: selectedMonth,
                calendar: calendar
            ),
            dayGroups: dayGroups,
            categoryLookup: LedgerCategoryLookup(
                categories: categories,
                subcategories: subcategories
            )
        )
    }

    private func content(transactions: [LedgerTransaction]) -> some View {
        let snapshot = contentSnapshot(for: transactions)

        return NavigationStack {
            List {
                Section {
                    summaryContent(
                        categoryExpenseInCents: snapshot.categoryExpenseInCents,
                        monthlyExpenseInCents: snapshot.monthlyExpenseInCents
                    )
                }

                Section {
                    if snapshot.details.isEmpty {
                        ContentUnavailableView(
                            "暂无分类明细",
                            systemImage: "list.bullet",
                            description: Text("当前分类在本月没有可展示的支出。")
                        )
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 20)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(snapshot.details) { item in
                            detailRow(
                                item,
                                categoryExpenseInCents: snapshot.categoryExpenseInCents
                            )
                        }
                    }
                } header: {
                    sectionTitle("分类明细")
                }

                transactionSections(
                    groups: snapshot.dayGroups,
                    categoryLookup: snapshot.categoryLookup
                )
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .navigationTitle(slice.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
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
    }

    private func summaryContent(
        categoryExpenseInCents: Int64,
        monthlyExpenseInCents: Int64
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(MoneyAmount.formatted(cents: categoryExpenseInCents))
                .font(.largeTitle.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(
                "占本月支出 \(percentageText(categoryExpenseInCents, of: monthlyExpenseInCents))"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    private func detailRow(
        _ item: ReportDetailItem,
        categoryExpenseInCents: Int64
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.name)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(MoneyAmount.formatted(cents: item.amountInCents))
                .monospacedDigit()
                .lineLimit(1)

            Text(percentageText(item.amountInCents, of: categoryExpenseInCents))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
        }
        .font(.body)
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func transactionSections(
        groups: [DayGroup],
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            Section {
                ForEach(group.transactions) { transaction in
                    transactionRow(
                        transaction,
                        categoryLookup: categoryLookup
                    )
                }
            } header: {
                VStack(alignment: .leading, spacing: 10) {
                    if index == 0 {
                        sectionTitle("具体账单")
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    private var monthTitle: String {
        selectedMonth.formatted(
            Date.FormatStyle()
                .year()
                .month(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    private func percentageText(_ amountInCents: Int64, of totalInCents: Int64) -> String {
        let percentage = totalInCents > 0
            ? Double(amountInCents) / Double(totalInCents)
            : 0
        return percentage.formatted(.percent.precision(.fractionLength(1)))
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
