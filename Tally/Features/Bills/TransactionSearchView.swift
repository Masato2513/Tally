//
//  TransactionSearchView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct TransactionSearchView: View {
    private struct DayGroup: Identifiable {
        let date: Date
        let transactions: [CurrentLedgerTransaction]

        var id: Date { date }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CurrentLedgerCategory.sortOrder)
    private var categories: [CurrentLedgerCategory]
    @Query(sort: \CurrentLedgerSubcategory.sortOrder)
    private var subcategories: [CurrentLedgerSubcategory]

    @State private var searchText = ""
    @State private var submittedKeyword = ""
    @State private var filters = TransactionSearchFilters()
    @State private var sortOrder: BillsSortOrder = .time
    @State private var displayLimit = TransactionSearchService.initialLimit
    @State private var transactions: [CurrentLedgerTransaction] = []
    @State private var totalCount = 0
    @State private var showsYear = false
    @State private var hasSearched = false
    @State private var isPresentingFilters = false
    @State private var editingTransaction: CurrentLedgerTransaction?
    @State private var pendingDeleteTransaction: CurrentLedgerTransaction?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteError = false
    @State private var isShowingSearchError = false

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        let categoryLookup = LedgerCategoryLookup(
            categories: categories,
            subcategories: subcategories
        )

        return List {
            if !hasSearched {
                Section {
                    ContentUnavailableView(
                        "搜索全部账单",
                        systemImage: "magnifyingglass",
                        description: Text("输入分类、子分类或备注，按键盘上的“搜索”开始查询。")
                    )
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowSeparator(.hidden)
                }
            } else {
                resultsTitle

                if transactions.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "未找到符合条件的账单",
                            systemImage: "magnifyingglass",
                            description: Text(
                                submittedKeyword.isEmpty
                                    ? "请尝试调整筛选条件。"
                                    : "请尝试修改关键词或筛选条件。"
                            )
                        )
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowSeparator(.hidden)
                    }
                } else if sortOrder == .time {
                    timeSortedSections(categoryLookup: categoryLookup)
                } else {
                    amountSortedSection(categoryLookup: categoryLookup)
                }

                paginationSection
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .navigationTitle("搜索账单")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "分类、子分类或备注"
        )
        .submitLabel(.search)
        .onSubmit(of: .search) {
            submitSearch(resetLimit: true)
        }
        .onChange(of: sortOrder) { _, _ in
            guard hasSearched else { return }
            displayLimit = TransactionSearchService.initialLimit
            refreshSearch()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isPresentingFilters = true
                } label: {
                    Label("筛选", systemImage: "line.3.horizontal.decrease")
                }

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
        .sheet(isPresented: $isPresentingFilters) {
            TransactionSearchFilterView(
                filters: filters,
                categories: categories
            ) { newFilters in
                filters = newFilters
                submitSearch(resetLimit: true)
            }
        }
        .sheet(item: $editingTransaction, onDismiss: refreshAfterMutation) { transaction in
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
        .alert("无法完成搜索", isPresented: $isShowingSearchError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("读取本地账单失败，请稍后重试。")
        }
    }

    private var resultsTitle: some View {
        Section {
            Text("账单明细（共 \(totalCount) 笔）")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private func timeSortedSections(
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        ForEach(dayGroups) { group in
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
                    transactions: group.transactions,
                    calendar: calendar,
                    includesYear: showsYear
                )
            }
        }
    }

    private func amountSortedSection(
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

    @ViewBuilder
    private var paginationSection: some View {
        if canShowMore || shouldShowMaximumLimitMessage {
            Section {
                if canShowMore {
                    Button("显示更多") {
                        displayLimit = min(
                            displayLimit + TransactionSearchService.initialLimit,
                            TransactionSearchService.maximumLimit
                        )
                        refreshSearch()
                    }
                    .frame(maxWidth: .infinity)
                }

                if shouldShowMaximumLimitMessage {
                    Text("仅显示前 300 笔，请通过搜索或筛选缩小范围")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private func transactionRow(
        _ transaction: CurrentLedgerTransaction,
        showsDate: Bool,
        categoryLookup: LedgerCategoryLookup
    ) -> some View {
        let display = categoryLookup.display(
            for: transaction,
            showsDate: showsDate,
            showsYear: showsYear
        )

        return BillsTransactionRow(display: display)
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

    private var dayGroups: [DayGroup] {
        Dictionary(grouping: transactions) {
            calendar.startOfDay(for: $0.date)
        }
        .map { DayGroup(date: $0.key, transactions: $0.value) }
        .sorted { $0.date > $1.date }
    }

    private var canShowMore: Bool {
        transactions.count < min(totalCount, TransactionSearchService.maximumLimit)
    }

    private var shouldShowMaximumLimitMessage: Bool {
        displayLimit >= TransactionSearchService.maximumLimit
            && totalCount > TransactionSearchService.maximumLimit
    }

    private func submitSearch(resetLimit: Bool) {
        submittedKeyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if resetLimit {
            displayLimit = TransactionSearchService.initialLimit
        }
        hasSearched = true
        refreshSearch()
    }

    private func refreshSearch() {
        guard hasSearched else { return }

        do {
            let snapshot = try TransactionSearchService.search(
                keyword: submittedKeyword,
                filters: filters,
                sortOrder: sortOrder,
                limit: displayLimit,
                in: modelContext,
                calendar: calendar
            )
            transactions = snapshot.transactions
            totalCount = snapshot.totalCount
            showsYear = snapshot.showsYear
        } catch {
            isShowingSearchError = true
        }
    }

    private func refreshAfterMutation() {
        refreshSearch()
    }

    private func deletePendingTransaction() {
        guard let transaction = pendingDeleteTransaction else { return }
        pendingDeleteTransaction = nil
        modelContext.delete(transaction)

        do {
            try modelContext.save()
            refreshSearch()
        } catch {
            modelContext.rollback()
            isShowingDeleteError = true
        }
    }
}

#Preview {
    NavigationStack {
        TransactionSearchView()
    }
    .modelContainer(
        for: [
            CurrentLedgerTransaction.self,
            CurrentLedgerCategory.self,
            CurrentLedgerSubcategory.self
        ],
        inMemory: true
    )
}
