//
//  LedgerCategoryColorTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class LedgerCategoryColorTests: XCTestCase {
    func testDefaultExpenseCategoriesUseTheirAssignedSystemColorRoles() {
        let expectedColors: [(String, LedgerCategoryColor)] = [
            ("expense.food", .orange),
            ("expense.shopping", .blue),
            ("expense.transportation", .cyan),
            ("expense.housing", .indigo),
            ("expense.dailyLife", .teal),
            ("expense.education", .purple),
            ("expense.relationships", .pink),
            ("expense.entertainment", .red),
            ("expense.travel", .mint),
            ("expense.medical", .green),
            ("expense.membershipCommunication", .brown)
        ]

        for (systemKey, expectedColor) in expectedColors {
            XCTAssertEqual(
                LedgerCategoryColor.systemColor(for: systemKey),
                expectedColor
            )
        }
    }

    func testCustomCategoryUsesPersistedColorAndDefaultsToBlue() {
        let custom = LedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .pink,
            sortOrder: 0,
            isSystem: false
        )
        let defaultColor = LedgerCategory(
            name: "其他",
            type: .expense,
            symbolName: "star",
            sortOrder: 1,
            isSystem: false
        )

        XCTAssertEqual(LedgerCategoryColor.resolve(for: custom), .pink)
        XCTAssertEqual(LedgerCategoryColor.resolve(for: defaultColor), .blue)
    }
}
