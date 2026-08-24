//
//  CategoryManagementView.swift
//  Tally
//

import SwiftData
import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [LedgerCategory]
    @Query private var subcategories: [LedgerSubcategory]

    @State private var selectedType: LedgerTransactionType = .expense
    @State private var isPresentingNewCategory = false
    @State private var errorMessage: String?
    @State private var editMode: EditMode = .inactive
    @State private var categoryOrderDraft: [UUID] = []
    @State private var pendingDeleteCategory: LedgerCategory?
    @State private var isShowingDeleteConfirmation = false

    private var managedCategories: [LedgerCategory] {
        CategoryManagementService.categories(of: selectedType, from: categories)
    }

    private var displayedCategories: [LedgerCategory] {
        guard editMode.isEditing else { return managedCategories }
        let categoriesByID = Dictionary(
            uniqueKeysWithValues: managedCategories.map { ($0.id, $0) }
        )
        return categoryOrderDraft.compactMap { categoriesByID[$0] }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("分类类型", selection: $selectedType) {
                ForEach(LedgerTransactionType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .disabled(editMode.isEditing)

            List {
                Section {
                    ForEach(displayedCategories) { category in
                        categoryListRow(category)
                    }
                    .onMove(perform: moveCategories)
                } footer: {
                    Text("隐藏的分类不会出现在新账单中，历史账单仍会完整保留。")
                }
            }
            .environment(\.editMode, $editMode)
            .overlay {
                if managedCategories.isEmpty {
                    ContentUnavailableView(
                        "暂无分类",
                        systemImage: "square.grid.2x2",
                        description: Text("点击右上角加号创建第一个分类。")
                    )
                }
            }
        }
        .navigationTitle("分类管理")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if editMode.isEditing {
                    Button("完成") {
                        saveCategoryOrder()
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("排序", systemImage: "arrow.up.arrow.down") {
                        beginCategorySorting()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(managedCategories.count < 2)
                }

                if !editMode.isEditing {
                    Button("新建分类", systemImage: "plus") {
                        isPresentingNewCategory = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("新建\(selectedType.title)分类")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewCategory) {
            CategoryEditorView(type: selectedType)
        }
        .alert("", isPresented: $isShowingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                pendingDeleteCategory = nil
            }
            Button("删除", role: .destructive, action: deletePendingCategory)
        } message: {
            Text("删除后不可恢复，该分类及其子分类将不再用于新账单，确定要删除吗？")
        }
        .alert("无法保存分类", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "发生未知错误。")
        }
    }

    @ViewBuilder
    private func categoryListRow(_ category: LedgerCategory) -> some View {
        if editMode.isEditing {
            categoryRow(category)
        } else {
            NavigationLink {
                CategoryDetailView(category: category)
            } label: {
                categoryRow(category)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !category.isSystem {
                    deleteButton(for: category)
                }
                visibilityButton(for: category)
            }
        }
    }

    private func categoryRow(_ category: LedgerCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: category.symbolName)
                .font(.title3)
                .foregroundStyle(LedgerCategoryColor.resolve(for: category).color)
                .opacity(category.isHidden ? 0.45 : 1)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .foregroundStyle(category.isHidden ? .secondary : .primary)

                Text(subcategoryDescription(for: category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if category.isHidden {
                Text("已隐藏")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func subcategoryDescription(for category: LedgerCategory) -> String {
        let count = subcategories.count {
            $0.categoryID == category.id && !$0.isSoftDeleted
        }
        let ownership = category.isSystem ? "系统分类" : "自定义分类"
        return count == 0 ? ownership : "\(ownership) · \(count) 个子分类"
    }

    private func visibilityButton(for category: LedgerCategory) -> some View {
        Button(category.isHidden ? "显示" : "隐藏") {
            setHidden(!category.isHidden, for: category)
        }
        .tint(category.isHidden ? .green : .orange)
    }

    private func deleteButton(for category: LedgerCategory) -> some View {
        Button("删除", systemImage: "trash", role: .destructive) {
            pendingDeleteCategory = category
            isShowingDeleteConfirmation = true
        }
        .tint(.red)
    }

    private func setHidden(_ hidden: Bool, for category: LedgerCategory) {
        do {
            try CategoryManagementService.setCategoryHidden(
                category,
                hidden: hidden,
                in: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePendingCategory() {
        guard let category = pendingDeleteCategory else { return }
        pendingDeleteCategory = nil

        do {
            try CategoryManagementService.softDeleteCategory(
                category,
                subcategories: subcategories,
                in: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveCategories(fromOffsets: IndexSet, toOffset: Int) {
        guard editMode.isEditing else { return }
        categoryOrderDraft.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    private func beginCategorySorting() {
        categoryOrderDraft = managedCategories.map(\.id)
        withAnimation {
            editMode = .active
        }
    }

    private func saveCategoryOrder() {
        let categoriesByID = Dictionary(
            uniqueKeysWithValues: managedCategories.map { ($0.id, $0) }
        )
        let reordered = categoryOrderDraft.compactMap { categoriesByID[$0] }

        do {
            try CategoryManagementService.applyCategoryOrder(
                reordered,
                in: modelContext
            )
            categoryOrderDraft = []
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
