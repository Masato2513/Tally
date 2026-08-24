//
//  TallySchemaMigrationTests.swift
//  TallyTests
//

import SwiftData
import XCTest
@testable import Tally

@MainActor
final class TallySchemaMigrationTests: XCTestCase {
    func testMigratesEarliestUnversionedStoreWithoutChangingLedgerData() throws {
        let location = try makeStoreLocation()
        defer { try? FileManager.default.removeItem(at: location.directory) }

        let categoryID = UUID()
        let subcategoryID = UUID()
        let transactionID = UUID()
        let transactionDate = Date(timeIntervalSince1970: 1_777_777_777)

        do {
            let schema = Schema([
                LedgerTransaction.self,
                LedgerCategory.self,
                LedgerSubcategory.self
            ])
            let configuration = ModelConfiguration(
                "TallyMigrationV1",
                schema: schema,
                url: location.store,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(
                LedgerCategory(
                    id: categoryID,
                    name: "历史分类",
                    type: .expense,
                    symbolName: "archivebox",
                    sortOrder: 3,
                    isSystem: false,
                    isHidden: true
                )
            )
            context.insert(
                LedgerSubcategory(
                    id: subcategoryID,
                    name: "历史子分类",
                    categoryID: categoryID,
                    sortOrder: 1,
                    isSystem: false
                )
            )
            context.insert(
                LedgerTransaction(
                    id: transactionID,
                    type: .expense,
                    amountInCents: 12_345,
                    date: transactionDate,
                    note: "迁移前备注",
                    categoryID: categoryID,
                    subcategoryID: subcategoryID
                )
            )
            try context.save()
        }

        do {
            let schema = TallyModelContainerFactory.currentSchema
            let configuration = ModelConfiguration(
                "TallyMigrationV2",
                schema: schema,
                url: location.store,
                cloudKitDatabase: .none
            )
            let container = try TallyModelContainerFactory.make(configuration: configuration)
            let context = ModelContext(container)

            let transactions = try context.fetch(FetchDescriptor<CurrentLedgerTransaction>())
            let categories = try context.fetch(FetchDescriptor<CurrentLedgerCategory>())
            let subcategories = try context.fetch(FetchDescriptor<CurrentLedgerSubcategory>())

            let transaction = try XCTUnwrap(transactions.first)
            XCTAssertEqual(transaction.id, transactionID)
            XCTAssertEqual(transaction.type, .expense)
            XCTAssertEqual(transaction.amountInCents, 12_345)
            XCTAssertEqual(transaction.date, transactionDate)
            XCTAssertEqual(transaction.note, "迁移前备注")
            XCTAssertEqual(transaction.categoryID, categoryID)
            XCTAssertEqual(transaction.subcategoryID, subcategoryID)

            let category = try XCTUnwrap(categories.first)
            XCTAssertEqual(category.id, categoryID)
            XCTAssertEqual(category.name, "历史分类")
            XCTAssertEqual(category.colorRawValue, LedgerCategoryColor.blue.rawValue)
            XCTAssertTrue(category.isHidden)
            XCTAssertFalse(category.isSoftDeleted)

            let subcategory = try XCTUnwrap(subcategories.first)
            XCTAssertEqual(subcategory.id, subcategoryID)
            XCTAssertEqual(subcategory.categoryID, categoryID)
            XCTAssertFalse(subcategory.isSoftDeleted)
        }
    }

    func testCurrentFileStorePersistsAcrossContainerReopen() throws {
        let location = try makeStoreLocation()
        defer { try? FileManager.default.removeItem(at: location.directory) }

        let transactionID = UUID()
        let categoryID = UUID()
        do {
            let container = try currentContainer(at: location.store)
            let context = ModelContext(container)
            context.insert(
                CurrentLedgerTransaction(
                    id: transactionID,
                    type: .income,
                    amountInCents: 88_800,
                    date: .now,
                    note: "文件数据库",
                    categoryID: categoryID
                )
            )
            try context.save()
        }

        do {
            let container = try currentContainer(at: location.store)
            let context = ModelContext(container)
            let transactions = try context.fetch(FetchDescriptor<CurrentLedgerTransaction>())
            XCTAssertEqual(transactions.count, 1)
            XCTAssertEqual(transactions.first?.id, transactionID)
            XCTAssertEqual(transactions.first?.amountInCents, 88_800)
        }
    }

    func testMigratesUnversionedColorAndSoftDeleteStore() throws {
        let location = try makeStoreLocation()
        defer { try? FileManager.default.removeItem(at: location.directory) }

        let categoryID = UUID()
        let subcategoryID = UUID()
        let transactionID = UUID()

        do {
            let schema = Schema([
                TallySchemaV1.LedgerTransaction.self,
                TallySchemaV1.LedgerCategory.self,
                TallySchemaV1.LedgerSubcategory.self
            ])
            let configuration = ModelConfiguration(
                "TallyUnversionedV1",
                schema: schema,
                url: location.store,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(
                TallySchemaV1.LedgerCategory(
                    id: categoryID,
                    name: "旧版自定义分类",
                    type: .expense,
                    symbolName: "pawprint",
                    color: .indigo,
                    sortOrder: 2,
                    isSystem: false,
                    isSoftDeleted: true
                )
            )
            context.insert(
                TallySchemaV1.LedgerSubcategory(
                    id: subcategoryID,
                    name: "旧版子分类",
                    categoryID: categoryID,
                    sortOrder: 0,
                    isSystem: false,
                    isSoftDeleted: true
                )
            )
            context.insert(
                TallySchemaV1.LedgerTransaction(
                    id: transactionID,
                    type: .expense,
                    amountInCents: 6_600,
                    date: Date(timeIntervalSince1970: 1_788_888_888),
                    note: "V1 历史账单",
                    categoryID: categoryID,
                    subcategoryID: subcategoryID
                )
            )
            try context.save()
        }

        let container = try currentContainer(at: location.store)
        let context = ModelContext(container)
        let transaction = try XCTUnwrap(
            try context.fetch(FetchDescriptor<CurrentLedgerTransaction>()).first
        )
        let category = try XCTUnwrap(
            try context.fetch(FetchDescriptor<CurrentLedgerCategory>()).first
        )
        let subcategory = try XCTUnwrap(
            try context.fetch(FetchDescriptor<CurrentLedgerSubcategory>()).first
        )

        XCTAssertEqual(transaction.id, transactionID)
        XCTAssertEqual(transaction.categoryID, categoryID)
        XCTAssertEqual(transaction.subcategoryID, subcategoryID)
        XCTAssertEqual(category.id, categoryID)
        XCTAssertEqual(category.colorRawValue, LedgerCategoryColor.indigo.rawValue)
        XCTAssertTrue(category.isSoftDeleted)
        XCTAssertEqual(subcategory.id, subcategoryID)
        XCTAssertTrue(subcategory.isSoftDeleted)
    }

    private func currentContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = TallyModelContainerFactory.currentSchema
        let configuration = ModelConfiguration(
            "TallyCurrent",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try TallyModelContainerFactory.make(configuration: configuration)
    }

    private func makeStoreLocation() throws -> (directory: URL, store: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TallyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return (directory, directory.appending(path: "Tally.store"))
    }
}
