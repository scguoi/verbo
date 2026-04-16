import AppKit
import SwiftUI

// MARK: - GeneralSettingsView

struct GeneralSettingsView: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // Behavior
            Section(String(localized: "settings.general.behavior_section")) {
                Picker(
                    String(localized: "settings.general.output_mode"),
                    selection: Binding(
                        get: { viewModel.config.general.outputMode },
                        set: { mode in
                            let updated = GeneralConfig(
                                outputMode: mode,
                                autoCollapseDelay: viewModel.config.general.autoCollapseDelay,
                                launchAtStartup: viewModel.config.general.launchAtStartup,
                                uiLanguage: viewModel.config.general.uiLanguage,
                                historyRetentionDays: viewModel.config.general.historyRetentionDays
                            )
                            viewModel.updateGeneral(updated)
                        }
                    )
                ) {
                    Text(String(localized: "settings.general.output_mode.simulate")).tag(OutputMode.simulate)
                    Text(String(localized: "settings.general.output_mode.clipboard")).tag(OutputMode.clipboard)
                }
                .pickerStyle(.segmented)

                LabeledContent(String(localized: "settings.general.auto_collapse_delay")) {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { viewModel.config.general.autoCollapseDelay },
                                set: { delay in
                                    let updated = GeneralConfig(
                                        outputMode: viewModel.config.general.outputMode,
                                        autoCollapseDelay: delay,
                                        launchAtStartup: viewModel.config.general.launchAtStartup,
                                        uiLanguage: viewModel.config.general.uiLanguage,
                                        historyRetentionDays: viewModel.config.general.historyRetentionDays
                                    )
                                    viewModel.updateGeneral(updated)
                                }
                            ),
                            in: 0...10,
                            step: 0.5
                        )
                        .frame(width: 160)
                        Text(String(format: "%.1f s", viewModel.config.general.autoCollapseDelay))
                            .font(DesignTokens.Typography.settingsCaption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .frame(width: 40)
                    }
                }
            }

            // Display
            Section(String(localized: "settings.general.display_section")) {
                Toggle(
                    String(localized: "settings.general.show_transcript_preview"),
                    isOn: Binding(
                        get: { viewModel.config.general.showTranscriptPreview },
                        set: { show in
                            let updated = GeneralConfig(
                                outputMode: viewModel.config.general.outputMode,
                                autoCollapseDelay: viewModel.config.general.autoCollapseDelay,
                                launchAtStartup: viewModel.config.general.launchAtStartup,
                                uiLanguage: viewModel.config.general.uiLanguage,
                                historyRetentionDays: viewModel.config.general.historyRetentionDays,
                                showTranscriptPreview: show
                            )
                            viewModel.updateGeneral(updated)
                        }
                    )
                )
            }

            // Language
            Section(String(localized: "settings.general.language_section")) {
                Picker(
                    String(localized: "settings.general.ui_language"),
                    selection: Binding(
                        get: { viewModel.config.general.uiLanguage },
                        set: { lang in
                            let previous = viewModel.config.general.uiLanguage
                            guard lang != previous else { return }
                            let updated = GeneralConfig(
                                outputMode: viewModel.config.general.outputMode,
                                autoCollapseDelay: viewModel.config.general.autoCollapseDelay,
                                launchAtStartup: viewModel.config.general.launchAtStartup,
                                uiLanguage: lang,
                                historyRetentionDays: viewModel.config.general.historyRetentionDays
                            )
                            viewModel.updateGeneral(updated)
                            promptRestartForLanguageChange()
                        }
                    )
                ) {
                    Text(String(localized: "settings.general.language.system")).tag(UILanguage.system)
                    Text(String(localized: "settings.general.language.zh")).tag(UILanguage.zh)
                    Text(String(localized: "settings.general.language.en")).tag(UILanguage.en)
                }
                .pickerStyle(.menu)
            }

            // Data
            Section(String(localized: "settings.general.data_section")) {
                Picker(
                    String(localized: "settings.general.history_retention"),
                    selection: Binding(
                        get: { viewModel.config.general.historyRetentionDays },
                        set: { days in
                            let updated = GeneralConfig(
                                outputMode: viewModel.config.general.outputMode,
                                autoCollapseDelay: viewModel.config.general.autoCollapseDelay,
                                launchAtStartup: viewModel.config.general.launchAtStartup,
                                uiLanguage: viewModel.config.general.uiLanguage,
                                historyRetentionDays: days
                            )
                            viewModel.updateGeneral(updated)
                        }
                    )
                ) {
                    Text(String(localized: "settings.general.retention.7_days")).tag(Optional(7))
                    Text(String(localized: "settings.general.retention.30_days")).tag(Optional(30))
                    Text(String(localized: "settings.general.retention.90_days")).tag(Optional(90))
                    Text(String(localized: "settings.general.retention.forever")).tag(Optional<Int>.none)
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Show a restart-required alert when the UI language changes. Bundle's
    /// localized-string cache is per-process, so already-rendered SwiftUI
    /// views cannot pick up a new language without a fresh launch.
    private func promptRestartForLanguageChange() {
        let alert = NSAlert()
        alert.messageText = String(localized: "settings.general.language.restart_title")
        alert.informativeText = String(localized: "settings.general.language.restart_message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "settings.general.language.restart_now"))
        alert.addButton(withTitle: String(localized: "settings.general.language.restart_later"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            relaunchApp()
        }
    }

    /// Relaunch the app: spawn a detached copy of ourselves after a short
    /// delay, then terminate the current process.
    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", url.path]
        try? task.run()
        // Give the new process a beat to start before we exit.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }
}
