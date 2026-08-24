//
//  TallyApp.swift
//  Tally
//
//  Created by . Xu on 2026/8/21.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct TallyApp: App {
    private enum StartupState {
        case ready(ModelContainer)
        case databaseUnavailable
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Tally",
        category: "数据库启动"
    )

    private let startupState: StartupState

    init() {
        do {
            let container: ModelContainer
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                let schema = TallyModelContainerFactory.currentSchema
                let configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                container = try TallyModelContainerFactory.make(configuration: configuration)
            } else {
                container = try TallyModelContainerFactory.make()
            }
            try DefaultCategorySeeder.seedIfNeeded(in: ModelContext(container))
            startupState = .ready(container)
        } catch {
            Self.logger.fault("无法初始化本地数据库：\(error.localizedDescription, privacy: .public)")
            startupState = .databaseUnavailable
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startupState {
            case let .ready(container):
                RootTabView()
                    .modelContainer(container)
            case .databaseUnavailable:
                DatabaseUnavailableView()
            }
        }
    }
}

private struct DatabaseUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label("无法打开账本", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("本地数据没有被清除。请重新启动 App 后再试；如果问题持续，请保留 App 并联系开发者处理。")
        }
    }
}
