//
//  TransactionSearchService.swift
//  Tally
//

import Foundation
import SwiftData

enum TransactionSearchTypeFilter: String, CaseIterable, Identifiable {
    case all
    case expense
    case income

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "全部"
        case .expense:
            "支出"
        case .income:
            "收入"
        }
    }

    var transactionType: LedgerTransactionType? {
        switch self {
        case .all:
            nil
        case .expense:
            .expense
        case .income:
            .income
        }
    }
}

struct TransactionSearchFilters: Equatable {
    var type: TransactionSearchTypeFilter = .all
    var categoryID: UUID?
    var startDate: Date?
    var endDate: Date?
    var minimumAmountInCents: Int64 = 0
    var maximumAmountInCents: Int64?
}

struct TransactionSearchSnapshot {
    let transactions: [CurrentLedgerTransaction]
    let totalCount: Int
    let showsYear: Bool
}

@MainActor
enum TransactionSearchService {
    static let initialLimit = 100
    static let maximumLimit = 300

    static func search(
        keyword: String,
        filters: TransactionSearchFilters,
        sortOrder: BillsSortOrder,
        limit: Int,
        in modelContext: ModelContext,
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) throws -> TransactionSearchSnapshot {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywordCategoryIDs = try matchingCategoryIDs(
            keyword: normalizedKeyword,
            in: modelContext
        )
        let keywordSubcategoryIDs = try matchingSubcategoryIDs(
            keyword: normalizedKeyword,
            in: modelContext
        )
        let predicate = transactionPredicate(
            keyword: normalizedKeyword,
            keywordCategoryIDs: keywordCategoryIDs,
            keywordSubcategoryIDs: keywordSubcategoryIDs,
            filters: filters,
            calendar: calendar
        )

        let countDescriptor = FetchDescriptor<CurrentLedgerTransaction>(
            predicate: predicate
        )
        let totalCount = try modelContext.fetchCount(countDescriptor)

        var resultDescriptor = FetchDescriptor<CurrentLedgerTransaction>(
            predicate: predicate,
            sortBy: sortDescriptors(for: sortOrder)
        )
        resultDescriptor.fetchLimit = min(
            max(limit, 1),
            maximumLimit
        )
        let transactions = try modelContext.fetch(resultDescriptor)

        return TransactionSearchSnapshot(
            transactions: transactions,
            totalCount: totalCount,
            showsYear: try shouldShowYear(
                predicate: predicate,
                totalCount: totalCount,
                relativeTo: referenceDate,
                calendar: calendar,
                in: modelContext
            )
        )
    }

    private static func matchingCategoryIDs(
        keyword: String,
        in modelContext: ModelContext
    ) throws -> [UUID] {
        guard !keyword.isEmpty else { return [] }
        let predicate = #Predicate<CurrentLedgerCategory> { category in
            category.name.localizedStandardContains(keyword)
        }
        let descriptor = FetchDescriptor<CurrentLedgerCategory>(predicate: predicate)
        return try modelContext.fetch(descriptor).map(\.id)
    }

    private static func matchingSubcategoryIDs(
        keyword: String,
        in modelContext: ModelContext
    ) throws -> [UUID?] {
        guard !keyword.isEmpty else { return [] }
        let predicate = #Predicate<CurrentLedgerSubcategory> { subcategory in
            subcategory.name.localizedStandardContains(keyword)
        }
        let descriptor = FetchDescriptor<CurrentLedgerSubcategory>(predicate: predicate)
        return try modelContext.fetch(descriptor).map { Optional($0.id) }
    }

    private static func transactionPredicate(
        keyword: String,
        keywordCategoryIDs: [UUID],
        keywordSubcategoryIDs: [UUID?],
        filters: TransactionSearchFilters,
        calendar: Calendar
    ) -> Predicate<CurrentLedgerTransaction> {
        let allowedTypeRawValues = filters.type.transactionType.map { [$0.rawValue] }
            ?? LedgerTransactionType.allCases.map(\.rawValue)
        let categoryFilterIDs = filters.categoryID.map { [$0] } ?? []
        let hasCategoryFilter = !categoryFilterIDs.isEmpty

        let startDate = filters.startDate.map(calendar.startOfDay(for:)) ?? .distantPast
        let endDate = filters.endDate
            .map(calendar.startOfDay(for:))
            .flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
            ?? .distantFuture

        let minimumAmount = max(filters.minimumAmountInCents, 0)
        let maximumAmount = filters.maximumAmountInCents ?? .max

        if keyword.isEmpty {
            return #Predicate<CurrentLedgerTransaction> { transaction in
                allowedTypeRawValues.contains(transaction.typeRawValue)
                    && (!hasCategoryFilter || categoryFilterIDs.contains(transaction.categoryID))
                    && transaction.date >= startDate
                    && transaction.date < endDate
                    && transaction.amountInCents >= minimumAmount
                    && transaction.amountInCents <= maximumAmount
            }
        }

        let matchesKeyword = #Expression<CurrentLedgerTransaction, Bool> { transaction in
            transaction.note.localizedStandardContains(keyword)
                || keywordCategoryIDs.contains(transaction.categoryID)
                || keywordSubcategoryIDs.contains(transaction.subcategoryID)
        }

        switch (filters.type.transactionType, filters.categoryID) {
        case let (type?, categoryID?):
            let typeRawValue = type.rawValue
            return #Predicate<CurrentLedgerTransaction> { transaction in
                matchesKeyword.evaluate(transaction)
                    && transaction.typeRawValue == typeRawValue
                    && transaction.categoryID == categoryID
                    && transaction.date >= startDate
                    && transaction.date < endDate
                    && transaction.amountInCents >= minimumAmount
                    && transaction.amountInCents <= maximumAmount
            }

        case let (type?, nil):
            let typeRawValue = type.rawValue
            return #Predicate<CurrentLedgerTransaction> { transaction in
                matchesKeyword.evaluate(transaction)
                    && transaction.typeRawValue == typeRawValue
                    && transaction.date >= startDate
                    && transaction.date < endDate
                    && transaction.amountInCents >= minimumAmount
                    && transaction.amountInCents <= maximumAmount
            }

        case let (nil, categoryID?):
            return #Predicate<CurrentLedgerTransaction> { transaction in
                matchesKeyword.evaluate(transaction)
                    && transaction.categoryID == categoryID
                    && transaction.date >= startDate
                    && transaction.date < endDate
                    && transaction.amountInCents >= minimumAmount
                    && transaction.amountInCents <= maximumAmount
            }

        case (nil, nil):
            return #Predicate<CurrentLedgerTransaction> { transaction in
                matchesKeyword.evaluate(transaction)
                    && transaction.date >= startDate
                    && transaction.date < endDate
                    && transaction.amountInCents >= minimumAmount
                    && transaction.amountInCents <= maximumAmount
            }
        }
    }

    private static func sortDescriptors(
        for sortOrder: BillsSortOrder
    ) -> [SortDescriptor<CurrentLedgerTransaction>] {
        switch sortOrder {
        case .time:
            [
                SortDescriptor(\CurrentLedgerTransaction.date, order: .reverse),
                SortDescriptor(\CurrentLedgerTransaction.id)
            ]
        case .amount:
            [
                SortDescriptor(\CurrentLedgerTransaction.amountInCents, order: .reverse),
                SortDescriptor(\CurrentLedgerTransaction.date, order: .reverse),
                SortDescriptor(\CurrentLedgerTransaction.id)
            ]
        }
    }

    private static func shouldShowYear(
        predicate: Predicate<CurrentLedgerTransaction>,
        totalCount: Int,
        relativeTo referenceDate: Date,
        calendar: Calendar,
        in modelContext: ModelContext
    ) throws -> Bool {
        guard totalCount > 0 else { return false }

        let oldest = try boundaryTransaction(
            predicate: predicate,
            order: .forward,
            in: modelContext
        )
        let newest = try boundaryTransaction(
            predicate: predicate,
            order: .reverse,
            in: modelContext
        )
        let referenceYear = calendar.component(.year, from: referenceDate)
        return [oldest, newest]
            .compactMap { $0 }
            .contains { calendar.component(.year, from: $0.date) != referenceYear }
    }

    private static func boundaryTransaction(
        predicate: Predicate<CurrentLedgerTransaction>,
        order: SortOrder,
        in modelContext: ModelContext
    ) throws -> CurrentLedgerTransaction? {
        var descriptor = FetchDescriptor<CurrentLedgerTransaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\CurrentLedgerTransaction.date, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
