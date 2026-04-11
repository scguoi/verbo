import SwiftUI

// MARK: - HistoryView

struct HistoryView: View {

    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            Divider()
            recordsList
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignTokens.Colors.stoneGray)
                .font(.system(size: 14))

            TextField(String(localized: "history.search_placeholder"), text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.settingsBody)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.stoneGray)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.ivory)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Picker(String(localized: "history.filter.scene"), selection: $viewModel.selectedSceneFilter) {
                Text(String(localized: "history.filter.all_scenes")).tag(Optional<String>.none)
                ForEach(viewModel.availableScenes, id: \.id) { scene in
                    Text(scene.name).tag(Optional(scene.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            Spacer()

            Button(String(localized: "history.clear_all")) {
                viewModel.clearAll()
            }
            .buttonStyle(.borderless)
            .font(DesignTokens.Typography.settingsCaption)
            .foregroundStyle(DesignTokens.Colors.errorCrimson)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.parchment)
    }

    // MARK: - Records List

    private var recordsList: some View {
        Group {
            if viewModel.groupedRecords.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.groupedRecords) { group in
                        Section {
                            ForEach(group.records) { record in
                                HistoryRowView(record: record)
                                    .listRowInsets(EdgeInsets(
                                        top: DesignTokens.Spacing.sm,
                                        leading: DesignTokens.Spacing.md,
                                        bottom: DesignTokens.Spacing.sm,
                                        trailing: DesignTokens.Spacing.md
                                    ))
                            }
                        } header: {
                            Text(group.label)
                                .font(DesignTokens.Typography.settingsTitle)
                                .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Colors.warmSilver)
            Text(String(localized: "history.empty"))
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.stoneGray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - HistoryRowView

private struct HistoryRowView: View {

    let record: HistoryRecord
    @State private var isHovering: Bool = false
    @State private var isExpanded: Bool = false

    private var statusColor: Color {
        switch record.outputStatus {
        case .inserted: Color.green
        case .copied: DesignTokens.Colors.focusBlue
        case .failed: DesignTokens.Colors.errorCrimson
        }
    }

    private var statusLabel: String {
        switch record.outputStatus {
        case .inserted: String(localized: "history.status.inserted")
        case .copied: String(localized: "history.status.copied")
        case .failed: String(localized: "history.status.failed")
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: record.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Main text
            Text(record.finalText)
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.nearBlack)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // LLM disclosure
            if record.hasLLMProcessing {
                DisclosureGroup(
                    isExpanded: $isExpanded,
                    content: {
                        Text(record.originalText)
                            .font(DesignTokens.Typography.settingsCaption)
                            .foregroundStyle(DesignTokens.Colors.oliveGray)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                    },
                    label: {
                        Text(String(localized: "history.view_original"))
                            .font(DesignTokens.Typography.settingsCaption)
                            .foregroundStyle(DesignTokens.Colors.focusBlue)
                    }
                )
            }

            // Metadata row
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(record.sceneName)
                    .font(DesignTokens.Typography.settingsCaption)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Colors.warmSand.opacity(0.6))
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    .clipShape(Capsule())

                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(DesignTokens.Typography.settingsCaption)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Text(formattedTime)
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)

                if isHovering {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.finalText, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DesignTokens.Colors.focusBlue)
                    .transition(.opacity)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.quick) {
                isHovering = hovering
            }
        }
    }
}
