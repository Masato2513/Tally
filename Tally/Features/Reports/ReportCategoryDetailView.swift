//
//  ReportCategoryDetailView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct ReportCategoryDetailView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let transactions: [CurrentLedgerTransaction]

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
    @Query(sort: \CurrentLedgerCategory.sortOrder)
    private var categories: [CurrentLedgerCategory]
    @Query(sort: \CurrentLedgerSubcategory.sortOrder)
    private var subcategories: [CurrentLedgerSubcategory]

    let slice: ExpenseCategorySlice
    let selectedMonth: Date

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var editingTransaction: CurrentLedgerTransaction?
    @State private var pendingDeleteTransaction: CurrentLedgerTransaction?
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
        for transactions: [CurrentLedgerTransaction]
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

    private func content(transactions: [CurrentLedgerTransaction]) -> some View {
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
                            "暂无构成数据",
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
                    sectionTitle("构成")
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
        let ratio = ratio(item.amountInCents, of: categoryExpenseInCents)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.name)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(MoneyAmount.formatted(cents: item.amountInCents))
                    .monospacedDigit()
                    .lineLimit(1)

                Text(percentageText(ratio))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 52, alignment: .trailing)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(categoryColor.opacity(0.14))

                    Capsule(style: .continuous)
                        .fill(categoryColor)
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 4)
        }
        .font(.body)
        .padding(.vertical, 4)
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
                        sectionTitle("账单")
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
        _ transaction: CurrentLedgerTransaction,
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        let display = categoryLookup.display(for: transaction, showsDate: false)

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

    private var categoryColor: Color {
        guard !slice.isMerged,
              let categoryID = slice.categoryIDs.first,
              let category = categories.first(where: { $0.id == categoryID })
        else {
            return LedgerCategoryColor.gray.color
        }

        return LedgerCategoryColor.resolve(for: category).color
    }

    private func percentageText(_ amountInCents: Int64, of totalInCents: Int64) -> String {
        percentageText(ratio(amountInCents, of: totalInCents))
    }

    private func percentageText(_ ratio: Double) -> String {
        ratio.formatted(.percent.precision(.fractionLength(1)))
    }

    private func ratio(_ amountInCents: Int64, of totalInCents: Int64) -> Double {
        guard totalInCents > 0 else { return 0 }
        return min(max(Double(amountInCents) / Double(totalInCents), 0), 1)
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
