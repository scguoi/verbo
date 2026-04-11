import SwiftUI

// MARK: - SettingsTab

private enum SettingsTab: String, CaseIterable {
    case scenes
    case providers
    case general
    case about
}

// MARK: - SettingsView

struct SettingsView: View {

    @Bindable var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .scenes

    var body: some View {
        TabView(selection: $selectedTab) {
            ScenesSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(String(localized: "settings.tab.scenes"), systemImage: "mic.circle")
                }
                .tag(SettingsTab.scenes)

            ProvidersSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(String(localized: "settings.tab.providers"), systemImage: "server.rack")
                }
                .tag(SettingsTab.providers)

            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(String(localized: "settings.tab.general"), systemImage: "gear")
                }
                .tag(SettingsTab.general)

            AboutView()
                .tabItem {
                    Label(String(localized: "settings.tab.about"), systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 600, minHeight: 450)
    }
}
