import SwiftUI

// MARK: - ScenesSettingsView

struct ScenesSettingsView: View {

    @Bindable var viewModel: SettingsViewModel
    @State private var editDraft: Scene?
    @State private var selectedSceneId: String?

    var body: some View {
        HSplitView {
            sceneList
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 240)

            if let draft = editDraft {
                SceneEditorView(
                    scene: draft,
                    availableSTTProviders: Array(viewModel.config.providers.stt.keys.sorted()),
                    availableLLMProviders: Array(viewModel.config.providers.llm.keys.sorted()),
                    onSave: { updated in
                        viewModel.saveEditingScene(updated)
                        editDraft = updated
                        selectedSceneId = updated.id
                    },
                    onCancel: {
                        viewModel.cancelEditingScene()
                        editDraft = nil
                        selectedSceneId = nil
                    }
                )
                .id(draft.id)
            } else {
                placeholderView
            }
        }
    }

    // MARK: - Scene List

    private var sceneList: some View {
        VStack(spacing: 0) {
            // Header with add button
            HStack {
                Text(String(localized: "settings.scenes.header"))
                    .font(DesignTokens.Typography.settingsTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Button(action: {
                    let newScene = viewModel.createScene()
                    selectedSceneId = newScene.id
                    editDraft = newScene
                    viewModel.startEditingScene(newScene)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "settings.scenes.add"))
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)

            Divider()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(viewModel.config.scenes) { scene in
                        SceneRowView(
                            scene: scene,
                            isDefault: scene.id == viewModel.config.defaultScene,
                            isSelected: scene.id == selectedSceneId,
                            onTap: {
                                selectedSceneId = scene.id
                                editDraft = scene
                                viewModel.startEditingScene(scene)
                            },
                            onSetDefault: { viewModel.selectSceneAsDefault(scene.id) },
                            onDelete: {
                                viewModel.deleteScene(scene.id)
                                if selectedSceneId == scene.id {
                                    selectedSceneId = nil
                                    editDraft = nil
                                }
                            }
                        )
                    }
                }
                .padding(DesignTokens.Spacing.sm)
            }
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack {
            Spacer()
            Text(String(localized: "settings.scenes.select_hint"))
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SceneRowView

private struct SceneRowView: View {

    let scene: Scene
    let isDefault: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onSetDefault: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var pipelineSummary: String {
        scene.pipeline.map { $0.type == .stt ? "STT" : "LLM" }.joined(separator: " → ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Row 1: Name + Default badge
            HStack {
                Text(scene.name)
                    .font(DesignTokens.Typography.settingsTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

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

            // Row 2: Pipeline summary + hotkey (single line)
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(pipelineSummary)
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Spacer()

                if let toggleHotkey = scene.hotkey.toggleRecord, !toggleHotkey.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 10))
                        Text(HotkeyManager.displayString(for: toggleHotkey))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignTokens.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Row 3: Actions (only set-default and delete; edit is via row tap)
            HStack(spacing: DesignTokens.Spacing.sm) {
                if !isDefault {
                    Button(String(localized: "settings.scenes.set_default")) {
                        onSetDefault()
                    }
                    .buttonStyle(.borderless)
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.focusBlue)
                }

                Spacer()

                Button(String(localized: "settings.scenes.delete")) {
                    onDelete()
                }
                .buttonStyle(.borderless)
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.errorCrimson)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(isSelected ? DesignTokens.Colors.terracotta : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isSelected {
            return DesignTokens.Colors.terracotta.opacity(0.12)
        } else if isHovered {
            return DesignTokens.Colors.surfaceElevated.opacity(0.5)
        }
        return .clear
    }
}

// MARK: - SceneEditorView

private struct SceneEditorView: View {

    @State private var draft: Scene
    let availableSTTProviders: [String]
    let availableLLMProviders: [String]
    let onSave: (Scene) -> Void
    let onCancel: () -> Void

    init(
        scene: Scene,
        availableSTTProviders: [String],
        availableLLMProviders: [String],
        onSave: @escaping (Scene) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: scene)
        self.availableSTTProviders = availableSTTProviders
        self.availableLLMProviders = availableLLMProviders
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
                HStack {
                    sectionHeader(String(localized: "settings.scenes.editor.pipeline"))
                    Spacer()
                    Menu {
                        Button(action: { addStep(.stt) }) {
                            Label(String(localized: "settings.scenes.editor.add_stt"), systemImage: "mic.fill")
                        }
                        Button(action: { addStep(.llm) }) {
                            Label(String(localized: "settings.scenes.editor.add_llm"), systemImage: "cpu")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                ForEach(draft.pipeline.indices, id: \.self) { idx in
                    EditablePipelineStepCard(
                        step: Binding(
                            get: { draft.pipeline[idx] },
                            set: { draft.pipeline[idx] = $0 }
                        ),
                        availableSTT: availableSTTProviders,
                        availableLLM: availableLLMProviders,
                        canMoveUp: idx > 0,
                        canMoveDown: idx < draft.pipeline.count - 1,
                        onMoveUp: { moveStep(from: idx, to: idx - 1) },
                        onMoveDown: { moveStep(from: idx, to: idx + 1) },
                        onDelete: { draft.pipeline.remove(at: idx) }
                    )
                }

                // Output Mode
                sectionHeader(String(localized: "settings.scenes.editor.output"))
                Picker("", selection: $draft.output) {
                    Text(String(localized: "settings.general.output_mode.simulate")).tag(OutputMode.simulate)
                    Text(String(localized: "settings.general.output_mode.clipboard")).tag(OutputMode.clipboard)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // Hotkeys
                sectionHeader(String(localized: "settings.scenes.editor.hotkeys"))
                HStack(spacing: DesignTokens.Spacing.md) {
                    Text(String(localized: "settings.scenes.editor.toggle_hotkey"))
                        .font(DesignTokens.Typography.settingsBody)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 100, alignment: .leading)
                    KeyRecorderView(shortcut: Binding(
                        get: { draft.hotkey.toggleRecord ?? "" },
                        set: {
                            draft.hotkey = SceneHotkey(
                                toggleRecord: $0.isEmpty ? nil : $0,
                                pushToTalk: draft.hotkey.pushToTalk
                            )
                        }
                    ))
                    Spacer()
                }
                HStack(spacing: DesignTokens.Spacing.md) {
                    Text(String(localized: "settings.scenes.editor.ptt_hotkey"))
                        .font(DesignTokens.Typography.settingsBody)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 100, alignment: .leading)
                    KeyRecorderView(shortcut: Binding(
                        get: { draft.hotkey.pushToTalk ?? "" },
                        set: {
                            draft.hotkey = SceneHotkey(
                                toggleRecord: draft.hotkey.toggleRecord,
                                pushToTalk: $0.isEmpty ? nil : $0
                            )
                        }
                    ))
                    Spacer()
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
            .foregroundStyle(DesignTokens.Colors.textSecondary)
    }

    private func addStep(_ type: PipelineStep.StepType) {
        let newStep: PipelineStep
        switch type {
        case .stt:
            newStep = PipelineStep(
                type: .stt,
                provider: availableSTTProviders.first ?? "iflytek",
                lang: "zh",
                prompt: nil
            )
        case .llm:
            newStep = PipelineStep(
                type: .llm,
                provider: availableLLMProviders.first ?? "openai",
                lang: nil,
                prompt: "{{input}}"
            )
        }
        draft.pipeline.append(newStep)
    }

    private func moveStep(from: Int, to: Int) {
        guard from != to, draft.pipeline.indices.contains(from), draft.pipeline.indices.contains(to) else { return }
        let step = draft.pipeline.remove(at: from)
        draft.pipeline.insert(step, at: to)
    }
}

// MARK: - EditablePipelineStepCard

private struct EditablePipelineStepCard: View {
    @Binding var step: PipelineStep
    let availableSTT: [String]
    let availableLLM: [String]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    private let labelColumnWidth: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Header: type icon + type label + controls
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: step.type == .stt ? "mic.fill" : "cpu")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.Colors.terracotta)
                    .frame(width: 20)

                Text(step.type.rawValue.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Spacer()

                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveDown)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(DesignTokens.Colors.errorCrimson)
                }
                .buttonStyle(.borderless)
            }

            // Aligned label/control rows
            Grid(alignment: .leadingFirstTextBaseline,
                 horizontalSpacing: DesignTokens.Spacing.sm,
                 verticalSpacing: DesignTokens.Spacing.sm) {
                GridRow {
                    Text(String(localized: "settings.scenes.editor.provider"))
                        .font(DesignTokens.Typography.settingsCaption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .frame(width: labelColumnWidth, alignment: .leading)
                    Picker("", selection: $step.provider) {
                        let options = step.type == .stt ? availableSTT : availableLLM
                        ForEach(options, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 180, alignment: .leading)
                    .gridColumnAlignment(.leading)
                }

                if step.type == .stt {
                    GridRow {
                        Text(String(localized: "settings.scenes.editor.language"))
                            .font(DesignTokens.Typography.settingsCaption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .frame(width: labelColumnWidth, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { step.lang ?? "zh" },
                            set: { step.lang = $0 }
                        )) {
                            Text("中文").tag("zh")
                            Text("English").tag("en")
                        }
                        .labelsHidden()
                        .frame(maxWidth: 180, alignment: .leading)
                        .gridColumnAlignment(.leading)
                    }
                } else {
                    GridRow(alignment: .top) {
                        Text(String(localized: "settings.scenes.editor.prompt"))
                            .font(DesignTokens.Typography.settingsCaption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .frame(width: labelColumnWidth, alignment: .leading)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 4) {
                            TextEditor(text: Binding(
                                get: { step.prompt ?? "" },
                                set: { step.prompt = $0 }
                            ))
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(4)
                            .background(DesignTokens.Colors.surfaceElevated.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(DesignTokens.Colors.borderAdaptive, lineWidth: 1)
                            )
                            Text(String(localized: "settings.scenes.editor.prompt_hint"))
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                        .gridColumnAlignment(.leading)
                    }
                }
            }
            .padding(.leading, 28)  // align under the type label, past the icon
        }
        .padding(DesignTokens.Spacing.md)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .strokeBorder(DesignTokens.Colors.borderAdaptive, lineWidth: 1)
        )
    }
}

// MARK: - PipelineStepCard

private struct PipelineStepCard: View {

    let step: PipelineStep

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: step.type == .stt ? "mic.fill" : "cpu")
                .font(.system(size: 16))
                .foregroundStyle(DesignTokens.Colors.terracotta)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.type.rawValue.uppercased())
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text(step.provider)
                    .font(DesignTokens.Typography.settingsBody)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                if let lang = step.lang {
                    Text(lang)
                        .font(DesignTokens.Typography.settingsCaption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .strokeBorder(DesignTokens.Colors.borderAdaptive, lineWidth: 1)
        )
    }
}
