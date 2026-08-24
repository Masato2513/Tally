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
    var colorRawValue: String = "blue"
    var sortOrder: Int
    var isSystem: Bool
    var isHidden: Bool
    var isSoftDeleted: Bool = false
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        systemKey: String? = nil,
        name: String,
        type: LedgerTransactionType,
        symbolName: String,
        color: LedgerCategoryColor = .blue,
        sortOrder: Int,
        isSystem: Bool,
        isHidden: Bool = false,
        isSoftDeleted: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.systemKey = systemKey
        self.name = name
        self.typeRawValue = type.rawValue
        self.symbolName = symbolName
        self.colorRawValue = color.rawValue
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.isHidden = isHidden
        self.isSoftDeleted = isSoftDeleted
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
