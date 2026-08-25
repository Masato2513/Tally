//
//  TransactionSearchFilterView.swift
//  Tally
//

import SwiftUI

struct TransactionSearchFilterView: View {
    private enum AmountField: Hashable {
        case minimum
        case maximum
    }

    @Environment(\.dismiss) private var dismiss

    private let categories: [CurrentLedgerCategory]
    private let onApply: (TransactionSearchFilters) -> Void

    @State private var type: TransactionSearchTypeFilter
    @State private var categoryID: UUID?
    @State private var limitsDate: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var minimumAmountText: String
    @State private var maximumAmountText: String
    @FocusState private var focusedAmountField: AmountField?

    private let calendar = Calendar.autoupdatingCurrent

    init(
        filters: TransactionSearchFilters,
        categories: [CurrentLedgerCategory],
        onApply: @escaping (TransactionSearchFilters) -> Void
    ) {
        let availableCategories = categories
            .filter { !$0.isHidden && !$0.isSoftDeleted }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type {
                    return lhs.type == .expense
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        self.categories = availableCategories
        self.onApply = onApply

        let monthStart = Calendar.autoupdatingCurrent.dateInterval(
            of: .month,
            for: .now
        )?.start ?? .now
        _type = State(initialValue: filters.type)
        _categoryID = State(
            initialValue: filters.categoryID.flatMap { selectedID in
                availableCategories.contains { $0.id == selectedID }
                    ? selectedID
                    : nil
            }
        )
        _limitsDate = State(
            initialValue: filters.startDate != nil || filters.endDate != nil
        )
        _startDate = State(initialValue: filters.startDate ?? monthStart)
        _endDate = State(initialValue: filters.endDate ?? .now)
        _minimumAmountText = State(
            initialValue: filters.minimumAmountInCents > 0
                ? MoneyAmount.editableText(cents: filters.minimumAmountInCents)
                : ""
        )
        _maximumAmountText = State(
            initialValue: filters.maximumAmountInCents.map {
                MoneyAmount.editableText(cents: $0)
            } ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    Picker("类型", selection: $type) {
                        ForEach(TransactionSearchTypeFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("分类") {
                    NavigationLink {
                        TransactionSearchCategorySelectionView(
                            selectedCategoryID: $categoryID,
                            categories: categories
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Text("分类")

                            Spacer(minLength: 12)

                            selectedCategoryLabel
                        }
                    }
                }

                Section {
                    Toggle("限制日期", isOn: $limitsDate)

                    if limitsDate {
                        DatePicker(
                            "开始日期",
                            selection: $startDate,
                            in: ...endDate,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "结束日期",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("日期")
                }

                Section {
                    HStack {
                        Text("最低金额")
                        Spacer()
                        TextField("不限", text: $minimumAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedAmountField, equals: .minimum)
                            .onChange(of: minimumAmountText) { oldValue, newValue in
                                minimumAmountText = MoneyAmount.acceptedEditingText(
                                    proposed: newValue,
                                    replacing: oldValue
                                )
                            }
                    }

                    HStack {
                        Text("最高金额")
                        Spacer()
                        TextField("不限", text: $maximumAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedAmountField, equals: .maximum)
                            .onChange(of: maximumAmountText) { oldValue, newValue in
                                maximumAmountText = MoneyAmount.acceptedEditingText(
                                    proposed: newValue,
                                    replacing: oldValue
                                )
                            }
                    }
                } header: {
                    Text("金额")
                }

                Section {
                    Button("重置筛选") {
                        resetFilters()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!hasActiveFilters)
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: type) { _, _ in
                focusedAmountField = nil
            }
            .onChange(of: categoryID) { _, _ in
                focusedAmountField = nil
            }
            .onChange(of: limitsDate) { _, _ in
                focusedAmountField = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        apply()
                    }
                    .disabled(validatedAmounts == nil)
                }
            }
        }
    }

    private var validatedAmounts: (minimum: Int64, maximum: Int64?)? {
        let minimum: Int64
        if minimumAmountText.isEmpty {
            minimum = 0
        } else {
            guard let parsedMinimum = MoneyAmount.centsAllowingZero(
                from: minimumAmountText
            ) else {
                return nil
            }
            minimum = parsedMinimum
        }

        let maximum: Int64?
        if maximumAmountText.isEmpty {
            maximum = nil
        } else {
            guard let parsedMaximum = MoneyAmount.centsAllowingZero(
                from: maximumAmountText
            ) else {
                return nil
            }
            maximum = parsedMaximum
        }

        guard maximum.map({ minimum <= $0 }) ?? true else { return nil }
        return (minimum, maximum)
    }

    private var hasActiveFilters: Bool {
        type != .all
            || categoryID != nil
            || limitsDate
            || !minimumAmountText.isEmpty
            || !maximumAmountText.isEmpty
    }

    @ViewBuilder
    private var selectedCategoryLabel: some View {
        if let category = categories.first(where: { $0.id == categoryID }) {
            HStack(spacing: 6) {
                Image(systemName: category.symbolName)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(
                        LedgerCategoryColor.resolve(for: category).color
                    )

                Text(category.name)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("全部分类")
                .foregroundStyle(.secondary)
        }
    }

    private func apply() {
        guard let amounts = validatedAmounts else { return }
        focusedAmountField = nil
        onApply(
            TransactionSearchFilters(
                type: type,
                categoryID: categoryID,
                startDate: limitsDate ? calendar.startOfDay(for: startDate) : nil,
                endDate: limitsDate ? calendar.startOfDay(for: endDate) : nil,
                minimumAmountInCents: amounts.minimum,
                maximumAmountInCents: amounts.maximum
            )
        )
        dismiss()
    }

    private func resetFilters() {
        focusedAmountField = nil
        type = .all
        categoryID = nil
        limitsDate = false
        minimumAmountText = ""
        maximumAmountText = ""
    }
}
