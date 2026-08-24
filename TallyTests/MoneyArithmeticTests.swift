//
//  MoneyArithmeticTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

final class MoneyArithmeticTests: XCTestCase {
    func testSumReturnsExactValueWithoutOverflow() {
        XCTAssertEqual(MoneyArithmetic.sum([100, 200, 300]), 600)
    }

    func testSumSaturatesAtIntegerBounds() {
        XCTAssertEqual(MoneyArithmetic.sum([Int64.max, 1]), .max)
        XCTAssertEqual(MoneyArithmetic.sum([Int64.min, -1]), .min)
    }

    func testSubtractSaturatesAtIntegerBounds() {
        XCTAssertEqual(MoneyArithmetic.subtract(200, from: 500), 300)
        XCTAssertEqual(MoneyArithmetic.subtract(-1, from: .max), .max)
        XCTAssertEqual(MoneyArithmetic.subtract(1, from: .min), .min)
    }
}
