//
//  LedgerTransaction.swift
//  Tally
//

import Foundation
import SwiftData

@Model
final class LedgerTransaction {
    var id: UUID
    var typeRawValue: String
    var amountInCents: Int64
    var date: Date
    var note: String
    var categoryID: UUID
    var subcategoryID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: LedgerTransactionType,
        amountInCents: Int64,
        date: Date,
        note: String = "",
        categoryID: UUID,
        subcategoryID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.amountInCents = amountInCents
        self.date = date
        self.note = note
        self.categoryID = categoryID
        self.subcategoryID = subcategoryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension LedgerTransaction {
    var type: LedgerTransactionType {
        get { LedgerTransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}

extension CurrentLedgerTransaction {
    var type: LedgerTransactionType {
        get { LedgerTransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}
