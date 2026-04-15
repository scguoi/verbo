import SwiftUI

// MARK: - ProvidersSettingsView

struct ProvidersSettingsView: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // STT Section
                sectionHeader(String(localized: "settings.providers.stt_title"))

                ForEach(Array(viewModel.config.providers.stt.keys.sorted()), id: \.self) { key in
                    if let sttConfig = viewModel.config.providers.stt[key] {
                        STTProviderCard(
                            name: key,
                            config: sttConfig,
                            onUpdate: { updated in
                                viewModel.updateSTTProvider(key, updated)
                            }
                        )
                    }
                }

                Divider()

                // LLM Section
                sectionHeader(String(localized: "settings.providers.llm_title"))

                ForEach(Array(viewModel.config.providers.llm.keys.sorted()), id: \.self) { key in
                    if let llmConfig = viewModel.config.providers.llm[key] {
                        LLMProviderCard(
                            name: key,
                            config: llmConfig,
                            onUpdate: { updated in
                                viewModel.updateLLMProvider(key, updated)
                            }
                        )
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Typography.settingsTitle)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
    }
}

// MARK: - STTProviderCard

private struct STTProviderCard: View {

    let name: String
    @State private var draft: STTProviderConfig
    let onUpdate: (STTProviderConfig) -> Void

    init(name: String, config: STTProviderConfig, onUpdate: @escaping (STTProviderConfig) -> Void) {
        self.name = name
        _draft = State(initialValue: config)
        self.onUpdate = onUpdate
    }

    var body: some View {
        GroupBox(name.capitalized) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ProviderField(
                    label: String(localized: "settings.providers.app_id"),
                    text: Binding(
                        get: { draft.appId },
                        set: { draft = STTProviderConfig(
                            appId: $0,
                            apiKey: draft.apiKey,
                            apiSecret: draft.apiSecret,
                            enabledLangs: draft.enabledLangs
                        )}
                    )
                )

                SecureProviderField(
                    label: String(localized: "settings.providers.api_key"),
                    text: Binding(
                        get: { draft.apiKey },
                        set: { draft = STTProviderConfig(
                            appId: draft.appId,
                            apiKey: $0,
                            apiSecret: draft.apiSecret,
                            enabledLangs: draft.enabledLangs
                        )}
                    )
                )

                SecureProviderField(
                    label: String(localized: "settings.providers.api_secret"),
                    text: Binding(
                        get: { draft.apiSecret },
                        set: { draft = STTProviderConfig(
                            appId: draft.appId,
                            apiKey: draft.apiKey,
                            apiSecret: $0,
                            enabledLangs: draft.enabledLangs
                        )}
                    )
                )

                HStack {
                    Spacer()
                    Button(String(localized: "settings.providers.save")) {
                        onUpdate(draft)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, DesignTokens.Spacing.xs)
        }
    }
}

// MARK: - LLMProviderCard

private struct LLMProviderCard: View {

    let name: String
    @State private var draft: LLMProviderConfig
    let onUpdate: (LLMProviderConfig) -> Void

    init(name: String, config: LLMProviderConfig, onUpdate: @escaping (LLMProviderConfig) -> Void) {
        self.name = name
        _draft = State(initialValue: config)
        self.onUpdate = onUpdate
    }

    var body: some View {
        GroupBox(name.capitalized) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                SecureProviderField(
                    label: String(localized: "settings.providers.api_key"),
                    text: Binding(
                        get: { draft.apiKey },
                        set: { draft = LLMProviderConfig(
                            apiKey: $0,
                            model: draft.model,
                            baseUrl: draft.baseUrl
                        )}
                    )
                )

                ProviderField(
                    label: String(localized: "settings.providers.model"),
                    text: Binding(
                        get: { draft.model },
                        set: { draft = LLMProviderConfig(
                            apiKey: draft.apiKey,
                            model: $0,
                            baseUrl: draft.baseUrl
                        )}
                    )
                )

                ProviderField(
                    label: String(localized: "settings.providers.base_url"),
                    text: Binding(
                        get: { draft.baseUrl },
                        set: { draft = LLMProviderConfig(
                            apiKey: draft.apiKey,
                            model: draft.model,
                            baseUrl: $0
                        )}
                    )
                )

                HStack {
                    Spacer()
                    Button(String(localized: "settings.providers.save")) {
                        onUpdate(draft)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, DesignTokens.Spacing.xs)
        }
    }
}

// MARK: - ProviderField

private struct ProviderField: View {

    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(DesignTokens.Typography.settingsBody)
        }
    }
}

// MARK: - SecureProviderField

private struct SecureProviderField: View {

    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)
            SecureField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(DesignTokens.Typography.settingsBody)
        }
    }
}
