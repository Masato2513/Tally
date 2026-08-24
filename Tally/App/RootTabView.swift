//
//  RootTabView.swift
//  Tally
//

import SwiftUI

struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("首页", systemImage: "house", value: .home) {
                NavigationStack {
                    HomeView()
                }
            }

            Tab("账单", systemImage: "list.bullet.rectangle", value: .bills) {
                NavigationStack {
                    BillsView()
                }
            }

            Tab("报表", systemImage: "chart.pie", value: .reports) {
                NavigationStack {
                    ReportsView()
                }
            }

            Tab("设置", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    RootTabView()
}
