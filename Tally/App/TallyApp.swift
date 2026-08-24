//
//  TallyApp.swift
//  Tally
//
//  Created by . Xu on 2026/8/21.
//

import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            LedgerTransaction.self,
            LedgerCategory.self,
            LedgerSubcategory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try DefaultCategorySeeder.seedIfNeeded(in: ModelContext(container))
            modelContainer = container
        } catch {
            fatalError("无法初始化本地数据库：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
