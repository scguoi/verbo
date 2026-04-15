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
        .overlay(alignment: .bottom) {
            if let toast = viewModel.saveToast {
                SaveToastView(toast: toast)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .animation(DesignTokens.Animation.standard, value: viewModel.saveToast)
    }
}

// MARK: - SaveToastView

private struct SaveToastView: View {
    let toast: SaveToast

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: toast.isSuccess
                  ? "checkmark.circle.fill"
                  : "xmark.octagon.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(toast.isSuccess
                                 ? Color.green
                                 : DesignTokens.Colors.errorCrimson)
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(DesignTokens.Colors.borderAdaptive, lineWidth: 0.5)
        )
        .shadow(color: DesignTokens.Shadows.ring, radius: 8, x: 0, y: 2)
    }
}
