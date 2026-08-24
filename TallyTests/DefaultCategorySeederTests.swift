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

        XCTAssertEqual(categories.count, 15)
        XCTAssertEqual(categories.filter { $0.type == .expense }.count, 12)
        XCTAssertEqual(categories.filter { $0.type == .income }.count, 3)
        XCTAssertEqual(subcategories.count, 57)
        XCTAssertTrue(categories.allSatisfy { UIImage(systemName: $0.symbolName) != nil })

        let repayment = try XCTUnwrap(
            categories.first { $0.systemKey == "expense.repayment" }
        )
        let repaymentSubcategories = subcategories
            .filter { $0.categoryID == repayment.id }
            .sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(repayment.name, "还款")
        XCTAssertEqual(repayment.symbolName, "creditcard")
        XCTAssertTrue(repayment.isSystem)
        XCTAssertEqual(
            repaymentSubcategories.map(\.name),
            ["信用卡", "房贷", "车贷", "消费分期", "网络借贷", "其他还款"]
        )
        XCTAssertTrue(repaymentSubcategories.allSatisfy(\.isSystem))
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

        XCTAssertEqual(reseededCategories.count, 15)
        XCTAssertEqual(reseededSubcategories.count, 57)
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
