//
//  RecordView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct RecordView: View {
    private enum Field: Hashable {
        case amount
        case note
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CurrentLedgerCategory.sortOrder) private var categories: [CurrentLedgerCategory]
    @Query(sort: \CurrentLedgerSubcategory.sortOrder) private var subcategories: [CurrentLedgerSubcategory]

    private let transaction: CurrentLedgerTransaction?

    @State private var transactionType: LedgerTransactionType
    @State private var selectedCategoryID: UUID?
    @State private var selectedSubcategoryID: UUID?
    @State private var amountText: String
    @State private var note: String
    @State private var transactionDate: Date
    @State private var isShowingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var saveFeedbackTrigger = 0
    @FocusState private var focusedField: Field?

    init(
        transaction: CurrentLedgerTransaction? = nil,
        initialDate: Date? = nil,
        initialCategoryID: UUID? = nil
    ) {
        let type = transaction?.type ?? .expense
        let categoryID = transaction?.categoryID ?? initialCategoryID
        let subcategoryID = transaction?.subcategoryID
        let amountText = transaction.map {
            MoneyAmount.editableText(cents: $0.amountInCents)
        } ?? ""
        let note = transaction?.note ?? ""
        let date = transaction?.date ?? initialDate ?? .now

        self.transaction = transaction
        _transactionType = State(initialValue: type)
        _selectedCategoryID = State(initialValue: categoryID)
        _selectedSubcategoryID = State(initialValue: subcategoryID)
        _amountText = State(initialValue: amountText)
        _note = State(initialValue: note)
        _transactionDate = State(initialValue: date)
    }

    private var selectableCategories: [CurrentLedgerCategory] {
        categories.filter {
            $0.type == transactionType
                && !$0.isSoftDeleted
                && (!$0.isHidden || $0.id == selectedCategoryID)
        }
    }

    private var selectableSubcategories: [CurrentLedgerSubcategory] {
        subcategories.filter {
            !$0.isSoftDeleted && (!$0.isHidden || $0.id == selectedSubcategoryID)
        }
    }

    private var historicalCategory: CurrentLedgerCategory? {
        guard let transaction else { return nil }
        return categories.first { $0.id == transaction.categoryID }
    }

    private var historicalSubcategory: CurrentLedgerSubcategory? {
        guard let subcategoryID = transaction?.subcategoryID else { return nil }
        return subcategories.first { $0.id == subcategoryID }
    }

    private var amountInCents: Int64? {
        MoneyAmount.cents(from: amountText)
    }

    private var defaultExpenseCategoryID: UUID? {
        RecordCategorySelectionService.defaultExpenseCategoryID(in: categories)
    }

    private var canSave: Bool {
        guard let transactionInput else { return false }
        return LedgerTransactionService.isValid(
            transactionInput,
            editing: transaction,
            categories: categories,
            subcategories: subcategories
        )
    }

    private var isEditing: Bool {
        transaction != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("收支类型", selection: $transactionType) {
                        ForEach(LedgerTransactionType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .simultaneousGesture(dismissKeyboardTap)
                }

                Section("分类") {
                    RecordCategoryPicker(
                        categories: selectableCategories,
                        subcategories: selectableSubcategories,
                        historicalCategory: historicalCategory,
                        historicalSubcategory: historicalSubcategory,
                        selectedCategoryID: $selectedCategoryID,
                        selectedSubcategoryID: $selectedSubcategoryID
                    )
                    .simultaneousGesture(dismissKeyboardTap)
                }

                Section("账单信息") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("¥")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)

                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title.weight(.semibold))
                            .monospacedDigit()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .focused($focusedField, equals: .amount)
                            .accessibilityLabel("金额")
                            .onChange(of: amountText) { previousValue, proposedValue in
                                amountText = MoneyAmount.acceptedEditingText(
                                    proposed: proposedValue,
                                    replacing: previousValue
                                )
                            }
                    }
                    .padding(.vertical, 4)

                    TextField("添加备注", text: $note)
                        .focused($focusedField, equals: .note)
                        .accessibilityLabel("备注")

                    DatePicker(
                        "日期",
                        selection: $transactionDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .simultaneousGesture(dismissKeyboardTap)

                }
            }
            .gesture(dismissKeyboardTap, including: .gesture)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityHint(
                            canSave ? "保存账单并关闭页面" : "请先选择分类并输入有效金额"
                        )
                }
            }
            .alert("无法保存账单", isPresented: $isShowingSaveError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .sensoryFeedback(.success, trigger: saveFeedbackTrigger)
            .onChange(of: transactionType) {
                selectedCategoryID = nil
                selectedSubcategoryID = nil
                selectDefaultExpenseCategoryIfNeeded()
            }
            .onAppear {
                if !isEditing {
                    focusedField = .amount
                }
            }
        }
    }

    private func selectDefaultExpenseCategoryIfNeeded() {
        guard !isEditing,
              transactionType == .expense,
              selectedCategoryID == nil,
              let defaultExpenseCategoryID
        else {
            return
        }

        selectedCategoryID = defaultExpenseCategoryID
        selectedSubcategoryID = nil
    }

    private var dismissKeyboardTap: some Gesture {
        TapGesture().onEnded {
            focusedField = nil
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        guard let transactionInput else { return }

        do {
            try LedgerTransactionService.save(
                transactionInput,
                editing: transaction,
                categories: categories,
                subcategories: subcategories,
                in: modelContext
            )
            saveFeedbackTrigger += 1
            dismiss()
        } catch let error as LedgerTransactionValidationError {
            saveErrorMessage = error.localizedDescription
            isShowingSaveError = true
        } catch {
            saveErrorMessage = "本地数据库写入失败，请稍后重试。"
            isShowingSaveError = true
        }
    }

    private var transactionInput: LedgerTransactionInput? {
        guard let amountInCents, let selectedCategoryID else { return nil }
        return LedgerTransactionInput(
            type: transactionType,
            amountInCents: amountInCents,
            date: transactionDate,
            note: note,
            categoryID: selectedCategoryID,
            subcategoryID: selectedSubcategoryID
        )
    }
}
