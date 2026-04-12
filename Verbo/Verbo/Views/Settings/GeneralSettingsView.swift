import SwiftUI

// MARK: - GeneralSettingsView

struct GeneralSettingsView: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // Global Hotkeys
            Section(String(localized: "settings.general.hotkeys_section")) {
                LabeledContent(String(localized: "settings.general.toggle_record")) {
                    hotkeyField(
                        rawValue: viewModel.config.globalHotkey.toggleRecord,
                        onCommit: { newValue in
                            let updatedHotkey = GlobalHotkey(
                                toggleRecord: newValue,
                                pushToTalk: viewModel.config.globalHotkey.pushToTalk
                            )
                            saveHotkey(updatedHotkey)
                        }
                    )
                }

                LabeledContent(String(localized: "settings.general.push_to_talk")) {
                    hotkeyField(
                        rawValue: viewModel.config.globalHotkey.pushToTalk ?? "",
                        onCommit: { newValue in
                            let updatedHotkey = GlobalHotkey(
                                toggleRecord: viewModel.config.globalHotkey.toggleRecord,
                                pushToTalk: newValue.isEmpty ? nil : newValue
                            )
                            saveHotkey(updatedHotkey)
                        }
                    )
                }
            }

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

            // Language
            Section(String(localized: "settings.general.language_section")) {
                Picker(
                    String(localized: "settings.general.ui_language"),
                    selection: Binding(
                        get: { viewModel.config.general.uiLanguage },
                        set: { lang in
                            let updated = GeneralConfig(
                                outputMode: viewModel.config.general.outputMode,
                                autoCollapseDelay: viewModel.config.general.autoCollapseDelay,
                                launchAtStartup: viewModel.config.general.launchAtStartup,
                                uiLanguage: lang,
                                historyRetentionDays: viewModel.config.general.historyRetentionDays
                            )
                            viewModel.updateGeneral(updated)
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

    /// Hotkey field: shows formatted shortcut as a chip, with a small TextField
    /// for editing the raw value underneath.
    @ViewBuilder
    private func hotkeyField(rawValue: String, onCommit: @escaping (String) -> Void) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Pretty formatted display chip
            Text(rawValue.isEmpty ? "—" : HotkeyManager.displayString(for: rawValue))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(minWidth: 60, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignTokens.Colors.surfaceElevated)
                )

            // Raw editable field
            TextField("", text: Binding(
                get: { rawValue },
                set: { onCommit($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11, design: .monospaced))
            .frame(width: 200)
        }
    }

    private func saveHotkey(_ hotkey: GlobalHotkey) {
        let newConfig = AppConfig(
            version: viewModel.config.version,
            defaultScene: viewModel.config.defaultScene,
            globalHotkey: hotkey,
            scenes: viewModel.config.scenes,
            providers: viewModel.config.providers,
            general: viewModel.config.general
        )
        viewModel.configManager.update(newConfig)
        try? viewModel.configManager.save()
    }
}
