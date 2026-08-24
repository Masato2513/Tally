//
//  CategoryManagementService.swift
//  Tally
//

import Foundation
import SwiftData

enum CategoryManagementError: LocalizedError, Equatable {
    case emptyName
    case nameTooLong(maximum: Int)
    case duplicateName
    case cannotEditSystemCategory
    case cannotDeleteSystemCategory
    case cannotModifyDeletedCategory

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "名称不能为空。"
        case let .nameTooLong(maximum):
            "名称不能超过 \(maximum) 个字符。"
        case .duplicateName:
            "同一层级中已经存在这个名称。"
        case .cannotEditSystemCategory:
            "系统分类不能修改名称或图标。"
        case .cannotDeleteSystemCategory:
            "系统分类不能删除。"
        case .cannotModifyDeletedCategory:
            "已删除的分类不能再修改。"
        }
    }
}

@MainActor
enum CategoryManagementService {
    static let maximumCategoryNameLength = 12
    static let maximumSubcategoryNameLength = 16

    static func categories(
        of type: LedgerTransactionType,
        from categories: [LedgerCategory]
    ) -> [LedgerCategory] {
        categories
            .filter { $0.type == type && !$0.isSoftDeleted }
            .sorted(by: categoryOrder)
    }

    static func subcategories(
        of categoryID: UUID,
        from subcategories: [LedgerSubcategory]
    ) -> [LedgerSubcategory] {
        subcategories
            .filter { $0.categoryID == categoryID && !$0.isSoftDeleted }
            .sorted(by: subcategoryOrder)
    }

    @discardableResult
    static func createCategory(
        name: String,
        type: LedgerTransactionType,
        symbolName: String,
        color: LedgerCategoryColor = .blue,
        among categories: [LedgerCategory],
        in context: ModelContext,
        now: Date = .now
    ) throws -> LedgerCategory {
        let normalizedName = try validatedName(
            name,
            maximumLength: maximumCategoryNameLength,
            existingNames: categories.lazy
                .filter { $0.type == type && !$0.isSoftDeleted }
                .map(\.name)
        )
        let nextOrder = categories.lazy
            .filter { $0.type == type && !$0.isSoftDeleted }
            .map(\.sortOrder)
            .max()
            .map { $0 + 1 } ?? 0
        let category = LedgerCategory(
            name: normalizedName,
            type: type,
            symbolName: symbolName,
            color: color,
            sortOrder: nextOrder,
            isSystem: false,
            createdAt: now,
            updatedAt: now
        )
        context.insert(category)
        try context.save()
        return category
    }

    static func updateCategory(
        _ category: LedgerCategory,
        name: String,
        symbolName: String,
        color: LedgerCategoryColor? = nil,
        among categories: [LedgerCategory],
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !category.isSystem else {
            throw CategoryManagementError.cannotEditSystemCategory
        }
        guard !category.isSoftDeleted else {
            throw CategoryManagementError.cannotModifyDeletedCategory
        }
        let normalizedName = try validatedName(
            name,
            maximumLength: maximumCategoryNameLength,
            existingNames: categories.lazy
                .filter {
                    $0.type == category.type
                        && $0.id != category.id
                        && !$0.isSoftDeleted
                }
                .map(\.name)
        )
        let previousName = category.name
        let previousSymbol = category.symbolName
        let previousColorRawValue = category.colorRawValue
        let previousUpdatedAt = category.updatedAt
        category.name = normalizedName
        category.symbolName = symbolName
        if let color {
            category.colorRawValue = color.rawValue
        }
        category.updatedAt = now
        do {
            try context.save()
        } catch {
            category.name = previousName
            category.symbolName = previousSymbol
            category.colorRawValue = previousColorRawValue
            category.updatedAt = previousUpdatedAt
            throw error
        }
    }

    static func setCategoryHidden(
        _ category: LedgerCategory,
        hidden: Bool,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !category.isSoftDeleted else {
            throw CategoryManagementError.cannotModifyDeletedCategory
        }
        let previousHidden = category.isHidden
        let previousUpdatedAt = category.updatedAt
        category.isHidden = hidden
        category.updatedAt = now
        do {
            try context.save()
        } catch {
            category.isHidden = previousHidden
            category.updatedAt = previousUpdatedAt
            throw error
        }
    }

    static func applyCategoryOrder(
        _ orderedCategories: [LedgerCategory],
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard orderedCategories.allSatisfy({ !$0.isSoftDeleted }) else {
            throw CategoryManagementError.cannotModifyDeletedCategory
        }
        let previousValues = orderedCategories.map { ($0, $0.sortOrder, $0.updatedAt) }
        for (index, category) in orderedCategories.enumerated() {
            category.sortOrder = index
            category.updatedAt = now
        }
        do {
            try context.save()
        } catch {
            for (category, sortOrder, updatedAt) in previousValues {
                category.sortOrder = sortOrder
                category.updatedAt = updatedAt
            }
            throw error
        }
    }

    @discardableResult
    static func createSubcategory(
        name: String,
        for category: LedgerCategory,
        among subcategories: [LedgerSubcategory],
        in context: ModelContext,
        now: Date = .now
    ) throws -> LedgerSubcategory {
        guard !category.isSoftDeleted else {
            throw CategoryManagementError.cannotModifyDeletedCategory
        }
        let siblings = subcategories.filter {
            $0.categoryID == category.id && !$0.isSoftDeleted
        }
        let normalizedName = try validatedName(
            name,
            maximumLength: maximumSubcategoryNameLength,
            existingNames: siblings.lazy.map(\.name)
        )
        let nextOrder = siblings.map(\.sortOrder).max().map { $0 + 1 } ?? 0
        let subcategory = LedgerSubcategory(
            name: normalizedName,
            categoryID: category.id,
            sortOrder: nextOrder,
            isSystem: false,
            createdAt: now,
            updatedAt: now
        )
        context.insert(subcategory)
        try context.save()
        return subcategory
    }

    static func updateSubcategory(
        _ subcategory: LedgerSubcategory,
        name: String,
        among subcategories: [LedgerSubcategory],
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !subcategory.isSystem else {
            throw CategoryManagementError.cannotEditSystemCategory
        }
        guard !subcategory.isSoftDeleted else {
            throw CategoryManagementError.cannotModifyDeletedCategory
        }
        let normalizedName = try validatedName(
            name,
            maximumLength: maximumSubcategoryNameLength,
            existingNames: subcategories.lazy
                .filter {
                    $0.categoryID == subcategory.categoryID && $0.id != subcategory.id
                        && !$0.isSoftDeleted
                }
                .map(\.name)
        )
        let previousName = subcategory.name
        let previousUpdatedAt = subcategory.updatedAt
        subcategory.name = normalizedName
        subcategory.updatedAt = now
        do {
            try context.save()
        } catch {
            subcategory.name = previousName
            subcategory.updatedAt = previousUpdatedAt
            throw error
        }
    }

    static func setSubcategoryHidden(
        _ subcategory: LedgerSubcategory,
        hidden: Bool,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !subcategory.isSoftDeleted else {
            throw CategoryManagementError.cannotModifyDeletedCategory
        }
        let previousHidden = subcategory.isHidden
        let previousUpdatedAt = subcategory.updatedAt
        subcategory.isHidden = hidden
        subcategory.updatedAt = now
        do {
            try context.save()
        } catch {
            subcategory.isHidden = previousHidden
            subcategory.updatedAt = previousUpdatedAt
            throw error
        }
    }

    static func applySubcategoryOrder(
        _ orderedSubcategories: [LedgerSubcategory],
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard orderedSubcategories.allSatisfy({ !$0.isSoftDeleted }) else {
            throw CategoryManagementError.cannotModifyDeletedCategory
        }
        let previousValues = orderedSubcategories.map { ($0, $0.sortOrder, $0.updatedAt) }
        for (index, subcategory) in orderedSubcategories.enumerated() {
            subcategory.sortOrder = index
            subcategory.updatedAt = now
        }
        do {
            try context.save()
        } catch {
            for (subcategory, sortOrder, updatedAt) in previousValues {
                subcategory.sortOrder = sortOrder
                subcategory.updatedAt = updatedAt
            }
            throw error
        }
    }

    static func softDeleteCategory(
        _ category: LedgerCategory,
        subcategories: [LedgerSubcategory],
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !category.isSystem else {
            throw CategoryManagementError.cannotDeleteSystemCategory
        }
        guard !category.isSoftDeleted else { return }

        let children = subcategories.filter {
            $0.categoryID == category.id && !$0.isSoftDeleted
        }
        let previousCategoryValue = (category.isSoftDeleted, category.updatedAt)
        let previousSubcategoryValues = children.map {
            ($0, $0.isSoftDeleted, $0.updatedAt)
        }

        category.isSoftDeleted = true
        category.updatedAt = now
        for child in children {
            child.isSoftDeleted = true
            child.updatedAt = now
        }

        do {
            try context.save()
        } catch {
            category.isSoftDeleted = previousCategoryValue.0
            category.updatedAt = previousCategoryValue.1
            for (subcategory, isSoftDeleted, updatedAt) in previousSubcategoryValues {
                subcategory.isSoftDeleted = isSoftDeleted
                subcategory.updatedAt = updatedAt
            }
            throw error
        }
    }

    static func softDeleteSubcategory(
        _ subcategory: LedgerSubcategory,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        guard !subcategory.isSystem else {
            throw CategoryManagementError.cannotDeleteSystemCategory
        }
        guard !subcategory.isSoftDeleted else { return }

        let previousValue = (subcategory.isSoftDeleted, subcategory.updatedAt)
        subcategory.isSoftDeleted = true
        subcategory.updatedAt = now

        do {
            try context.save()
        } catch {
            subcategory.isSoftDeleted = previousValue.0
            subcategory.updatedAt = previousValue.1
            throw error
        }
    }
}

private extension CategoryManagementService {
    static func validatedName<S: Sequence>(
        _ name: String,
        maximumLength: Int,
        existingNames: S
    ) throws -> String where S.Element == String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw CategoryManagementError.emptyName
        }
        guard normalizedName.count <= maximumLength else {
            throw CategoryManagementError.nameTooLong(maximum: maximumLength)
        }
        guard !existingNames.contains(where: {
            $0.compare(normalizedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            throw CategoryManagementError.duplicateName
        }
        return normalizedName
    }

    static func categoryOrder(_ lhs: LedgerCategory, _ rhs: LedgerCategory) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func subcategoryOrder(_ lhs: LedgerSubcategory, _ rhs: LedgerSubcategory) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
