//
//  SettingsView.swift
//  Tally
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    CategoryManagementView()
                } label: {
                    Label("分类管理", systemImage: "square.grid.2x2")
                }
            }
        }
        .navigationTitle("设置")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
