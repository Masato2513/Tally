//
//  LedgerCategory.swift
//  Tally
//

import Foundation
import SwiftData

@Model
final class LedgerCategory {
    var id: UUID
    var systemKey: String?
    var name: String
    var typeRawValue: String
    var symbolName: String
    var sortOrder: Int
    var isSystem: Bool
    var isHidden: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        systemKey: String? = nil,
        name: String,
        type: LedgerTransactionType,
        symbolName: String,
        sortOrder: Int,
        isSystem: Bool,
        isHidden: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.systemKey = systemKey
        self.name = name
        self.typeRawValue = type.rawValue
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension LedgerCategory {
    var type: LedgerTransactionType {
        get { LedgerTransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}

extension CurrentLedgerCategory {
    var type: LedgerTransactionType {
        get { LedgerTransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}
