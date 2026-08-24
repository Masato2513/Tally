//
//  CategoryEditorView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [CurrentLedgerCategory]

    let type: LedgerTransactionType
    let category: CurrentLedgerCategory?

    @State private var name: String
    @State private var symbolName: String
    @State private var categoryColor: LedgerCategoryColor
    @State private var selectedDetent: PresentationDetent = .large
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    private static let symbolNames = [
        "fork.knife", "cup.and.saucer", "cart", "bag", "tshirt",
        "car", "bus", "bicycle", "fuelpump", "house",
        "wrench.and.screwdriver", "shippingbox", "book", "graduationcap", "gift",
        "heart", "gamecontroller", "film", "dumbbell", "suitcase",
        "airplane", "cross.case", "pills", "phone", "antenna.radiowaves.left.and.right",
        "briefcase", "banknote", "chart.line.uptrend.xyaxis", "star", "pawprint",
        "leaf", "person.2", "sparkles", "music.note", "camera"
    ]

    init(type: LedgerTransactionType, category: CurrentLedgerCategory? = nil) {
        self.type = type
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _symbolName = State(initialValue: category?.symbolName ?? "star")
        _categoryColor = State(
            initialValue: category.map { LedgerCategoryColor.resolve(for: $0) } ?? .blue
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例如：宠物", text: $name)
                        .textInputAutocapitalization(.never)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { isNameFocused = false }
                } header: {
                    Text("名称")
                } footer: {
                    Text("最多 \(CategoryManagementService.maximumCategoryNameLength) 个字符")
                }

                if category?.isSystem != true {
                    Section("颜色") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 56), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(LedgerCategoryColor.selectableColors) { color in
                                colorButton(color)
                            }
                        }
                        .padding(.vertical, 6)
                        .simultaneousGesture(dismissKeyboardTap)
                    }
                }

                Section("图标") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 48), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(Self.symbolNames, id: \.self) { symbol in
                            symbolButton(symbol)
                        }
                    }
                    .padding(.vertical, 6)
                    .simultaneousGesture(dismissKeyboardTap)
                }
            }
            .gesture(dismissKeyboardTap, including: .gesture)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if category == nil {
                    isNameFocused = true
                }
            }
            .alert("无法保存分类", isPresented: errorBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "发生未知错误。")
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }

    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = symbolName == symbol

        return Button {
            isNameFocused = false
            symbolName = symbol
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isSelected ? categoryColor.color : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("图标 \(symbol)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func colorButton(_ color: LedgerCategoryColor) -> some View {
        let isSelected = categoryColor == color

        return Button {
            isNameFocused = false
            categoryColor = color
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(color.color)
                    .frame(width: 28, height: 28)

                Text(color.title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("分类颜色，\(color.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var dismissKeyboardTap: some Gesture {
        TapGesture().onEnded {
            isNameFocused = false
        }
    }

    private var canSave: Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalizedName.isEmpty
            && normalizedName.count <= CategoryManagementService.maximumCategoryNameLength
    }

    private func save() {
        do {
            if let category {
                try CategoryManagementService.updateCategory(
                    category,
                    name: name,
                    symbolName: symbolName,
                    color: categoryColor,
                    among: categories,
                    in: modelContext
                )
            } else {
                try CategoryManagementService.createCategory(
                    name: name,
                    type: type,
                    symbolName: symbolName,
                    color: categoryColor,
                    among: categories,
                    in: modelContext
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
