//
//  LedgerSubcategory.swift
//  Tally
//

import Foundation
import SwiftData

@Model
final class LedgerSubcategory {
    var id: UUID
    var systemKey: String?
    var name: String
    var categoryID: UUID
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
        categoryID: UUID,
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
        self.categoryID = categoryID
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.isHidden = isHidden
        self.isSoftDeleted = isSoftDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
