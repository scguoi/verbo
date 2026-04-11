import SwiftUI

// MARK: - ScenesSettingsView

struct ScenesSettingsView: View {

    @Bindable var viewModel: SettingsViewModel
    @State private var editDraft: Scene?

    var body: some View {
        HSplitView {
            sceneList
                .frame(minWidth: 200, maxWidth: 260)

            if viewModel.isEditingScene, let draft = editDraft {
                SceneEditorView(
                    scene: draft,
                    onSave: { updated in
                        viewModel.saveEditingScene(updated)
                        editDraft = nil
                    },
                    onCancel: {
                        viewModel.cancelEditingScene()
                        editDraft = nil
                    }
                )
            } else {
                placeholderView
            }
        }
        .onChange(of: viewModel.editingScene) { _, newValue in
            editDraft = newValue
        }
    }

    // MARK: - Scene List

    private var sceneList: some View {
        VStack(spacing: 0) {
            List(viewModel.config.scenes) { scene in
                SceneRowView(
                    scene: scene,
                    isDefault: scene.id == viewModel.config.defaultScene,
                    onSetDefault: { viewModel.selectSceneAsDefault(scene.id) },
                    onEdit: {
                        viewModel.startEditingScene(scene)
                    },
                    onDelete: { viewModel.deleteScene(scene.id) }
                )
                .listRowInsets(EdgeInsets(
                    top: DesignTokens.Spacing.xs,
                    leading: DesignTokens.Spacing.sm,
                    bottom: DesignTokens.Spacing.xs,
                    trailing: DesignTokens.Spacing.sm
                ))
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack {
            Spacer()
            Text(String(localized: "settings.scenes.select_hint"))
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.stoneGray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SceneRowView

private struct SceneRowView: View {

    let scene: Scene
    let isDefault: Bool
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var pipelineSummary: String {
        scene.pipeline.map { step in
            step.type == .stt ? "STT" : "LLM"
        }.joined(separator: " → ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text(scene.name)
                    .font(DesignTokens.Typography.settingsTitle)
                    .foregroundStyle(DesignTokens.Colors.nearBlack)

                Spacer()

                if isDefault {
                    Text(String(localized: "settings.scenes.default_badge"))
                        .font(DesignTokens.Typography.settingsCaption)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(DesignTokens.Colors.terracotta.opacity(0.15))
                        .foregroundStyle(DesignTokens.Colors.terracotta)
                        .clipShape(Capsule())
                }
            }

            Text(pipelineSummary)
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.stoneGray)

            if let toggleHotkey = scene.hotkey.toggleRecord {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10))
                    Text(toggleHotkey)
                        .font(DesignTokens.Typography.settingsCaption)
                }
                .foregroundStyle(DesignTokens.Colors.oliveGray)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, 2)
                .background(DesignTokens.Colors.warmSand.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                if !isDefault {
                    Button(String(localized: "settings.scenes.set_default")) {
                        onSetDefault()
                    }
                    .buttonStyle(.borderless)
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.focusBlue)
                }

                Button(String(localized: "settings.scenes.edit")) {
                    onEdit()
                }
                .buttonStyle(.borderless)
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.focusBlue)

                Spacer()

                Button(String(localized: "settings.scenes.delete")) {
                    onDelete()
                }
                .buttonStyle(.borderless)
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.errorCrimson)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - SceneEditorView

private struct SceneEditorView: View {

    @State private var draft: Scene
    let onSave: (Scene) -> Void
    let onCancel: () -> Void

    init(scene: Scene, onSave: @escaping (Scene) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: scene)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Name
                sectionHeader(String(localized: "settings.scenes.editor.name"))
                TextField(String(localized: "settings.scenes.editor.name_placeholder"), text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .font(DesignTokens.Typography.settingsBody)

                // Pipeline
                sectionHeader(String(localized: "settings.scenes.editor.pipeline"))
                ForEach(draft.pipeline.indices, id: \.self) { idx in
                    PipelineStepCard(step: draft.pipeline[idx])
                }

                // Hotkeys
                sectionHeader(String(localized: "settings.scenes.editor.hotkeys"))
                HStack {
                    Text(String(localized: "settings.scenes.editor.toggle_hotkey"))
                        .font(DesignTokens.Typography.settingsBody)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    Spacer()
                    TextField(
                        String(localized: "settings.scenes.editor.hotkey_placeholder"),
                        text: Binding(
                            get: { draft.hotkey.toggleRecord ?? "" },
                            set: { draft = Scene(
                                id: draft.id,
                                name: draft.name,
                                hotkey: SceneHotkey(
                                    toggleRecord: $0.isEmpty ? nil : $0,
                                    pushToTalk: draft.hotkey.pushToTalk
                                ),
                                pipeline: draft.pipeline,
                                output: draft.output
                            )}
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .font(DesignTokens.Typography.settingsBody)
                }

                HStack {
                    Text(String(localized: "settings.scenes.editor.ptt_hotkey"))
                        .font(DesignTokens.Typography.settingsBody)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    Spacer()
                    TextField(
                        String(localized: "settings.scenes.editor.hotkey_placeholder"),
                        text: Binding(
                            get: { draft.hotkey.pushToTalk ?? "" },
                            set: { draft = Scene(
                                id: draft.id,
                                name: draft.name,
                                hotkey: SceneHotkey(
                                    toggleRecord: draft.hotkey.toggleRecord,
                                    pushToTalk: $0.isEmpty ? nil : $0
                                ),
                                pipeline: draft.pipeline,
                                output: draft.output
                            )}
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .font(DesignTokens.Typography.settingsBody)
                }

                // Save / Cancel
                HStack {
                    Spacer()
                    Button(String(localized: "settings.scenes.editor.cancel")) {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(String(localized: "settings.scenes.editor.save")) {
                        onSave(draft)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Typography.settingsTitle)
            .foregroundStyle(DesignTokens.Colors.charcoalWarm)
    }
}

// MARK: - PipelineStepCard

private struct PipelineStepCard: View {

    let step: PipelineStep

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: step.type == .stt ? "mic.fill" : "cpu")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Colors.terracotta)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.type.rawValue.uppercased())
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                Text(step.provider)
                    .font(DesignTokens.Typography.settingsBody)
                    .foregroundStyle(DesignTokens.Colors.nearBlack)
                if let lang = step.lang {
                    Text(lang)
                        .font(DesignTokens.Typography.settingsCaption)
                        .foregroundStyle(DesignTokens.Colors.oliveGray)
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.parchment)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Colors.borderWarm, lineWidth: 1)
        )
    }
}
