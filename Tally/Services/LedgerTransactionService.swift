//
//  LedgerTransactionService.swift
//  Tally
//

import Foundation
import SwiftData

struct LedgerTransactionInput {
    let type: LedgerTransactionType
    let amountInCents: Int64
    let date: Date
    let note: String
    let categoryID: UUID
    let subcategoryID: UUID?
}

enum LedgerTransactionValidationError: LocalizedError, Equatable {
    case invalidAmount
    case invalidCategory
    case invalidSubcategory
    case noteTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            "金额必须大于 0。"
        case .invalidCategory:
            "请选择有效分类。"
        case .invalidSubcategory:
            "请选择属于当前分类的有效子分类。"
        case .noteTooLarge:
            "备注内容过长，请精简后再保存。"
        }
    }
}

@MainActor
enum LedgerTransactionService {
    /// 防止异常粘贴把超大文本直接写入本地数据库；正常备注远小于该上限。
    static let maximumNoteSizeInBytes = 16 * 1024

    static func isValid(
        _ input: LedgerTransactionInput,
        editing transaction: CurrentLedgerTransaction?,
        categories: [CurrentLedgerCategory],
        subcategories: [CurrentLedgerSubcategory]
    ) -> Bool {
        (try? validate(
            input,
            editing: transaction,
            categories: categories,
            subcategories: subcategories
        )) != nil
    }

    static func validate(
        _ input: LedgerTransactionInput,
        editing transaction: CurrentLedgerTransaction?,
        categories: [CurrentLedgerCategory],
        subcategories: [CurrentLedgerSubcategory]
    ) throws {
        guard input.amountInCents > 0 else {
            throw LedgerTransactionValidationError.invalidAmount
        }
        guard input.note.utf8.count <= maximumNoteSizeInBytes else {
            throw LedgerTransactionValidationError.noteTooLarge
        }

        let keepsHistoricalSelection = transaction.map {
            $0.type == input.type
                && $0.categoryID == input.categoryID
                && $0.subcategoryID == input.subcategoryID
        } ?? false
        if keepsHistoricalSelection {
            return
        }

        guard categories.contains(where: {
            $0.id == input.categoryID
                && $0.type == input.type
                && !$0.isSoftDeleted
        }) else {
            throw LedgerTransactionValidationError.invalidCategory
        }

        if let subcategoryID = input.subcategoryID {
            guard subcategories.contains(where: {
                $0.id == subcategoryID
                    && $0.categoryID == input.categoryID
                    && !$0.isSoftDeleted
            }) else {
                throw LedgerTransactionValidationError.invalidSubcategory
            }
        }
    }

    @discardableResult
    static func save(
        _ input: LedgerTransactionInput,
        editing transaction: CurrentLedgerTransaction?,
        categories: [CurrentLedgerCategory],
        subcategories: [CurrentLedgerSubcategory],
        in context: ModelContext,
        now: Date = .now
    ) throws -> CurrentLedgerTransaction {
        try validate(
            input,
            editing: transaction,
            categories: categories,
            subcategories: subcategories
        )

        let savedTransaction: CurrentLedgerTransaction
        if let transaction {
            transaction.type = input.type
            transaction.amountInCents = input.amountInCents
            transaction.date = input.date
            transaction.note = input.note.trimmingCharacters(in: .whitespacesAndNewlines)
            transaction.categoryID = input.categoryID
            transaction.subcategoryID = input.subcategoryID
            transaction.updatedAt = now
            savedTransaction = transaction
        } else {
            let newTransaction = CurrentLedgerTransaction(
                type: input.type,
                amountInCents: input.amountInCents,
                date: input.date,
                note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryID: input.categoryID,
                subcategoryID: input.subcategoryID,
                createdAt: now,
                updatedAt: now
            )
            context.insert(newTransaction)
            savedTransaction = newTransaction
        }

        do {
            try context.save()
            return savedTransaction
        } catch {
            context.rollback()
            throw error
        }
    }
}
