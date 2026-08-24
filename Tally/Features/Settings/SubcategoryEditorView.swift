//
//  SubcategoryEditorView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct SubcategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var subcategories: [LedgerSubcategory]

    let category: LedgerCategory
    let subcategory: LedgerSubcategory?

    @State private var name: String
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    init(category: LedgerCategory, subcategory: LedgerSubcategory? = nil) {
        self.category = category
        self.subcategory = subcategory
        _name = State(initialValue: subcategory?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例如：宠物用品", text: $name)
                        .textInputAutocapitalization(.never)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { isNameFocused = false }
                } header: {
                    Text("名称")
                } footer: {
                    Text("属于“\(category.name)”，最多 \(CategoryManagementService.maximumSubcategoryNameLength) 个字符")
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
            .onAppear { isNameFocused = true }
            .alert("无法保存分类", isPresented: errorBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "发生未知错误。")
            }
        }
        .presentationDetents([.medium])
    }

    private var dismissKeyboardTap: some Gesture {
        TapGesture().onEnded {
            isNameFocused = false
        }
    }

    private var canSave: Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalizedName.isEmpty
            && normalizedName.count <= CategoryManagementService.maximumSubcategoryNameLength
    }

    private func save() {
        do {
            if let subcategory {
                try CategoryManagementService.updateSubcategory(
                    subcategory,
                    name: name,
                    among: subcategories,
                    in: modelContext
                )
            } else {
                try CategoryManagementService.createSubcategory(
                    name: name,
                    for: category,
                    among: subcategories,
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
