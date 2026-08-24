//
//  CategoryDetailView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSubcategories: [LedgerSubcategory]

    let category: LedgerCategory

    @State private var isPresentingCategoryEditor = false
    @State private var isPresentingNewSubcategory = false
    @State private var editingSubcategory: LedgerSubcategory?
    @State private var errorMessage: String?
    @State private var editMode: EditMode = .inactive
    @State private var subcategoryOrderDraft: [UUID] = []
    @State private var pendingDeleteSubcategory: LedgerSubcategory?
    @State private var isShowingDeleteConfirmation = false

    private var subcategories: [LedgerSubcategory] {
        CategoryManagementService.subcategories(
            of: category.id,
            from: allSubcategories
        )
    }

    private var displayedSubcategories: [LedgerSubcategory] {
        guard editMode.isEditing else { return subcategories }
        let subcategoriesByID = Dictionary(
            uniqueKeysWithValues: subcategories.map { ($0.id, $0) }
        )
        return subcategoryOrderDraft.compactMap { subcategoriesByID[$0] }
    }

    var body: some View {
        List {
            Section {
                categoryInfoRow
                    .disabled(editMode.isEditing)

                Toggle("在新账单中显示", isOn: visibilityBinding)
                    .disabled(editMode.isEditing)
            } footer: {
                Text("隐藏只影响以后记账时的选择列表，不会修改或删除历史账单。")
            }

            Section {
                if subcategories.isEmpty {
                    Text("暂无子分类")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(displayedSubcategories) { subcategory in
                        subcategoryListRow(subcategory)
                    }
                    .onMove(perform: moveSubcategories)
                }
            } header: {
                HStack {
                    Text("子分类")

                    Spacer()

                    if subcategories.count > 1 || editMode.isEditing {
                        Button(editMode.isEditing ? "完成" : "排序") {
                            if editMode.isEditing {
                                saveSubcategoryOrder()
                            } else {
                                beginSubcategorySorting()
                            }
                        }
                        .fontWeight(editMode.isEditing ? .semibold : .regular)
                    }
                }
                .textCase(nil)
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(category.name)
        .toolbar {
            if !editMode.isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建子分类", systemImage: "plus") {
                        isPresentingNewSubcategory = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("为\(category.name)新建子分类")
                }
            }
        }
        .sheet(isPresented: $isPresentingCategoryEditor) {
            CategoryEditorView(type: category.type, category: category)
        }
        .sheet(isPresented: $isPresentingNewSubcategory) {
            SubcategoryEditorView(category: category)
        }
        .sheet(item: $editingSubcategory) { subcategory in
            SubcategoryEditorView(category: category, subcategory: subcategory)
        }
        .alert("", isPresented: $isShowingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                pendingDeleteSubcategory = nil
            }
            Button("删除", role: .destructive, action: deletePendingSubcategory)
        } message: {
            Text("删除后不可恢复，确定要删除这个子分类吗？")
        }
        .alert("无法保存分类", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "发生未知错误。")
        }
    }

    @ViewBuilder
    private var categoryInfoRow: some View {
        if category.isSystem {
            categoryInfoContent
        } else {
            Button {
                isPresentingCategoryEditor = true
            } label: {
                categoryInfoContent
            }
            .buttonStyle(.plain)
            .accessibilityHint("编辑分类")
        }
    }

    private var categoryInfoContent: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(category.isSystem ? "系统分类" : "自定义分类")
                    .foregroundStyle(.secondary)

                if !category.isSystem {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        } label: {
            Label {
                Text(category.name)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: category.symbolName)
                    .foregroundStyle(LedgerCategoryColor.resolve(for: category).color)
            }
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private func subcategoryListRow(_ subcategory: LedgerSubcategory) -> some View {
        if editMode.isEditing {
            subcategoryLabel(subcategory)
        } else {
            subcategoryRow(subcategory)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !subcategory.isSystem {
                        subcategoryDeleteButton(for: subcategory)
                    }
                    subcategoryVisibilityButton(for: subcategory)
                }
        }
    }

    @ViewBuilder
    private func subcategoryRow(_ subcategory: LedgerSubcategory) -> some View {
        if subcategory.isSystem {
            subcategoryLabel(subcategory)
        } else {
            Button {
                editingSubcategory = subcategory
            } label: {
                subcategoryLabel(subcategory)
            }
            .buttonStyle(.plain)
            .accessibilityHint("编辑子分类")
        }
    }

    private func subcategoryLabel(_ subcategory: LedgerSubcategory) -> some View {
        HStack {
            Text(subcategory.name)
                .foregroundStyle(subcategory.isHidden ? .secondary : .primary)

            Spacer()

            if subcategory.isHidden {
                Text("已隐藏")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !subcategory.isSystem && !editMode.isEditing {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { !category.isHidden },
            set: { isVisible in
                do {
                    try CategoryManagementService.setCategoryHidden(
                        category,
                        hidden: !isVisible,
                        in: modelContext
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }

    private func subcategoryVisibilityButton(for subcategory: LedgerSubcategory) -> some View {
        Button(subcategory.isHidden ? "显示" : "隐藏") {
            do {
                try CategoryManagementService.setSubcategoryHidden(
                    subcategory,
                    hidden: !subcategory.isHidden,
                    in: modelContext
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .tint(subcategory.isHidden ? .green : .orange)
    }

    private func subcategoryDeleteButton(for subcategory: LedgerSubcategory) -> some View {
        Button("删除", systemImage: "trash", role: .destructive) {
            pendingDeleteSubcategory = subcategory
            isShowingDeleteConfirmation = true
        }
        .tint(.red)
    }

    private func deletePendingSubcategory() {
        guard let subcategory = pendingDeleteSubcategory else { return }
        pendingDeleteSubcategory = nil

        do {
            try CategoryManagementService.softDeleteSubcategory(
                subcategory,
                in: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveSubcategories(fromOffsets: IndexSet, toOffset: Int) {
        guard editMode.isEditing else { return }
        subcategoryOrderDraft.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    private func beginSubcategorySorting() {
        subcategoryOrderDraft = subcategories.map(\.id)
        withAnimation {
            editMode = .active
        }
    }

    private func saveSubcategoryOrder() {
        let subcategoriesByID = Dictionary(
            uniqueKeysWithValues: subcategories.map { ($0.id, $0) }
        )
        let reordered = subcategoryOrderDraft.compactMap { subcategoriesByID[$0] }

        do {
            try CategoryManagementService.applySubcategoryOrder(
                reordered,
                in: modelContext
            )
            subcategoryOrderDraft = []
            withAnimation {
                editMode = .inactive
            }
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
