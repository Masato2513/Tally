//
//  TallySchema.swift
//  Tally
//

import Foundation
import SwiftData

/// 开发期最早写入磁盘的数据结构。
///
/// 模型类型保持原有名称，用来识别尚未包含分类颜色与逻辑删除字段的未版本化数据库。
enum TallySchemaV0: VersionedSchema {
    static let versionIdentifier = Schema.Version(0, 9, 0)

    static var models: [any PersistentModel.Type] {
        [
            LedgerTransaction.self,
            LedgerCategory.self,
            LedgerSubcategory.self
        ]
    }
}

/// 引入统一分类颜色与逻辑删除后的数据结构。
enum TallySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            LedgerTransaction.self,
            LedgerCategory.self,
            LedgerSubcategory.self
        ]
    }

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
}

/// 当前应用使用的数据结构。旧类型只用于识别和迁移历史数据库。
enum TallySchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            LedgerTransaction.self,
            LedgerCategory.self,
            LedgerSubcategory.self
        ]
    }

    @Model
    final class LedgerTransaction {
        #Index<LedgerTransaction>([\.date])

        @Attribute(.unique) var id: UUID
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

    @Model
    final class LedgerCategory {
        @Attribute(.unique) var id: UUID
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

    @Model
    final class LedgerSubcategory {
        @Attribute(.unique) var id: UUID
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
}

typealias CurrentLedgerTransaction = TallySchemaV2.LedgerTransaction
typealias CurrentLedgerCategory = TallySchemaV2.LedgerCategory
typealias CurrentLedgerSubcategory = TallySchemaV2.LedgerSubcategory

enum TallyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TallySchemaV0.self, TallySchemaV1.self, TallySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: TallySchemaV0.self, toVersion: TallySchemaV1.self),
            .lightweight(fromVersion: TallySchemaV1.self, toVersion: TallySchemaV2.self)
        ]
    }
}

enum TallyModelContainerFactory {
    static var currentSchema: Schema {
        Schema(versionedSchema: TallySchemaV2.self)
    }

    static func make(configuration: ModelConfiguration? = nil) throws -> ModelContainer {
        let schema = currentSchema
        let configuration = configuration
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(
            for: schema,
            migrationPlan: TallyMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
