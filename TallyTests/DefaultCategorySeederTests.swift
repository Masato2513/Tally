//
//  DefaultCategorySeederTests.swift
//  TallyTests
//

import SwiftData
import UIKit
import XCTest
@testable import Tally

@MainActor
final class DefaultCategorySeederTests: XCTestCase {
    func testSeedsAllDefaultCategories() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        try DefaultCategorySeeder.seedIfNeeded(in: context)

        let categories = try context.fetch(FetchDescriptor<LedgerCategory>())
        let subcategories = try context.fetch(FetchDescriptor<LedgerSubcategory>())

        XCTAssertEqual(categories.count, 14)
        XCTAssertEqual(categories.filter { $0.type == .expense }.count, 11)
        XCTAssertEqual(categories.filter { $0.type == .income }.count, 3)
        XCTAssertEqual(subcategories.count, 51)
        XCTAssertTrue(categories.allSatisfy { UIImage(systemName: $0.symbolName) != nil })
    }

    func testRepeatedSeedingIsIdempotentAndPreservesUserState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try DefaultCategorySeeder.seedIfNeeded(in: context)

        let categories = try context.fetch(FetchDescriptor<LedgerCategory>())
        let foodCategory = try XCTUnwrap(categories.first { $0.systemKey == "expense.food" })
        foodCategory.isHidden = true
        try context.save()

        try DefaultCategorySeeder.seedIfNeeded(in: context)

        let reseededCategories = try context.fetch(FetchDescriptor<LedgerCategory>())
        let reseededSubcategories = try context.fetch(FetchDescriptor<LedgerSubcategory>())
        let reseededFoodCategory = try XCTUnwrap(
            reseededCategories.first { $0.systemKey == "expense.food" }
        )

        XCTAssertEqual(reseededCategories.count, 14)
        XCTAssertEqual(reseededSubcategories.count, 51)
        XCTAssertTrue(reseededFoodCategory.isHidden)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            LedgerTransaction.self,
            LedgerCategory.self,
            LedgerSubcategory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

