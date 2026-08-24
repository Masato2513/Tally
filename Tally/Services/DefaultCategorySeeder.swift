//
//  DefaultCategorySeeder.swift
//  Tally
//

import Foundation
import SwiftData

@MainActor
enum DefaultCategorySeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        let existingCategories = try context.fetch(FetchDescriptor<LedgerCategory>())
        let existingSubcategories = try context.fetch(FetchDescriptor<LedgerSubcategory>())

        var categoriesBySystemKey: [String: LedgerCategory] = [:]
        for category in existingCategories {
            if let systemKey = category.systemKey, categoriesBySystemKey[systemKey] == nil {
                categoriesBySystemKey[systemKey] = category
            }
        }

        var existingSubcategoryKeys = Set(existingSubcategories.compactMap(\.systemKey))
        let now = Date.now

        for (categoryIndex, definition) in definitions.enumerated() {
            let category: LedgerCategory
            if let existingCategory = categoriesBySystemKey[definition.systemKey] {
                category = existingCategory
            } else {
                category = LedgerCategory(
                    systemKey: definition.systemKey,
                    name: definition.name,
                    type: definition.type,
                    symbolName: definition.symbolName,
                    sortOrder: categoryIndex,
                    isSystem: true,
                    createdAt: now,
                    updatedAt: now
                )
                context.insert(category)
                categoriesBySystemKey[definition.systemKey] = category
            }

            for (subcategoryIndex, subcategoryDefinition) in definition.subcategories.enumerated() {
                guard !existingSubcategoryKeys.contains(subcategoryDefinition.systemKey) else {
                    continue
                }

                let subcategory = LedgerSubcategory(
                    systemKey: subcategoryDefinition.systemKey,
                    name: subcategoryDefinition.name,
                    categoryID: category.id,
                    sortOrder: subcategoryIndex,
                    isSystem: true,
                    createdAt: now,
                    updatedAt: now
                )
                context.insert(subcategory)
                existingSubcategoryKeys.insert(subcategoryDefinition.systemKey)
            }
        }

        try context.save()
    }
}

private extension DefaultCategorySeeder {
    struct CategoryDefinition {
        let systemKey: String
        let name: String
        let type: LedgerTransactionType
        let symbolName: String
        let subcategories: [SubcategoryDefinition]
    }

    struct SubcategoryDefinition {
        let systemKey: String
        let name: String
    }

    static let definitions: [CategoryDefinition] = [
        expenseCategory(
            key: "expense.food",
            name: "餐饮",
            symbol: "fork.knife",
            subcategories: [
                ("meals", "三餐"),
                ("groceries", "柴米油盐"),
                ("ingredients", "食材"),
                ("snacks", "零食"),
                ("milkTea", "奶茶"),
                ("coffee", "咖啡")
            ]
        ),
        expenseCategory(
            key: "expense.shopping",
            name: "购物",
            symbol: "bag",
            subcategories: [
                ("daily", "日常"),
                ("clothing", "鞋服"),
                ("digital", "数码"),
                ("kitchen", "厨房用品"),
                ("appliances", "电器")
            ]
        ),
        expenseCategory(
            key: "expense.transportation",
            name: "交通",
            symbol: "car",
            subcategories: [
                ("publicTransit", "公交地铁"),
                ("taxi", "打车"),
                ("privateCar", "私家车"),
                ("sharedBike", "共享单车"),
                ("flight", "飞机"),
                ("coach", "大巴"),
                ("train", "火车"),
                ("fuel", "加油")
            ]
        ),
        expenseCategory(
            key: "expense.housing",
            name: "居住",
            symbol: "house",
            subcategories: [
                ("rent", "房租"),
                ("utilities", "物业水电"),
                ("repairs", "维修")
            ]
        ),
        expenseCategory(
            key: "expense.dailyLife",
            name: "日常",
            symbol: "shippingbox",
            subcategories: [
                ("delivery", "快递"),
                ("haircut", "理发")
            ]
        ),
        expenseCategory(
            key: "expense.education",
            name: "学习",
            symbol: "book",
            subcategories: [
                ("onlineCourse", "网课"),
                ("books", "书籍"),
                ("training", "培训")
            ]
        ),
        expenseCategory(
            key: "expense.relationships",
            name: "人情",
            symbol: "gift",
            subcategories: [
                ("gifts", "送礼"),
                ("redEnvelope", "发红包"),
                ("filial", "孝心"),
                ("treating", "请客")
            ]
        ),
        expenseCategory(
            key: "expense.entertainment",
            name: "娱乐",
            symbol: "gamecontroller",
            subcategories: [
                ("leisure", "休闲"),
                ("movies", "电影"),
                ("fitness", "健身"),
                ("dating", "约会"),
                ("games", "游戏")
            ]
        ),
        expenseCategory(
            key: "expense.travel",
            name: "旅游",
            symbol: "suitcase",
            subcategories: [
                ("tickets", "门票"),
                ("hotel", "酒店"),
                ("tour", "团费")
            ]
        ),
        expenseCategory(
            key: "expense.medical",
            name: "医疗",
            symbol: "cross.case",
            subcategories: [
                ("medicine", "药品"),
                ("treatment", "治疗"),
                ("consultation", "就诊"),
                ("hospitalization", "住院"),
                ("healthCare", "保健")
            ]
        ),
        expenseCategory(
            key: "expense.membershipCommunication",
            name: "会员/通讯",
            symbol: "antenna.radiowaves.left.and.right",
            subcategories: [
                ("subscription", "订阅续费"),
                ("phoneBill", "话费")
            ]
        ),
        expenseCategory(
            key: "expense.repayment",
            name: "还款",
            symbol: "creditcard",
            subcategories: [
                ("creditCard", "信用卡"),
                ("mortgage", "房贷"),
                ("carLoan", "车贷"),
                ("consumerInstallment", "消费分期"),
                ("onlineLoan", "网络借贷"),
                ("otherRepayment", "其他还款")
            ]
        ),
        incomeCategory(
            key: "income.career",
            name: "职业收入",
            symbol: "briefcase",
            subcategories: [
                ("salary", "薪资"),
                ("housingFund", "公积金"),
                ("bonus", "奖金")
            ]
        ),
        incomeCategory(
            key: "income.investment",
            name: "投资回报",
            symbol: "chart.line.uptrend.xyaxis",
            subcategories: [
                ("fundsStocks", "基金股票"),
                ("interest", "利息")
            ]
        ),
        incomeCategory(
            key: "income.other",
            name: "其他收益",
            symbol: "plus.circle",
            subcategories: []
        )
    ]

    static func expenseCategory(
        key: String,
        name: String,
        symbol: String,
        subcategories: [(String, String)]
    ) -> CategoryDefinition {
        category(
            key: key,
            name: name,
            type: .expense,
            symbol: symbol,
            subcategories: subcategories
        )
    }

    static func incomeCategory(
        key: String,
        name: String,
        symbol: String,
        subcategories: [(String, String)]
    ) -> CategoryDefinition {
        category(
            key: key,
            name: name,
            type: .income,
            symbol: symbol,
            subcategories: subcategories
        )
    }

    static func category(
        key: String,
        name: String,
        type: LedgerTransactionType,
        symbol: String,
        subcategories: [(String, String)]
    ) -> CategoryDefinition {
        CategoryDefinition(
            systemKey: key,
            name: name,
            type: type,
            symbolName: symbol,
            subcategories: subcategories.map {
                SubcategoryDefinition(systemKey: "\(key).\($0.0)", name: $0.1)
            }
        )
    }
}
