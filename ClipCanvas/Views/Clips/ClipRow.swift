import SwiftUI
import SwiftData

struct ClipRow: View {
    let clip: Clip
    let compact: Bool
    var isSelecting = false
    var isSelected = false
    var isExpanded = false
    var onSelect: (() -> Void)?
    var onDetails: (() -> Void)?
    var onPrimaryAction: (() -> Void)?

    @Environment(\.modelContext) private var context
    @AppStorage(ClipboardService.accessEnabledKey) private var clipboardAccessEnabled = false
    @ObservedObject private var revealStore = SensitiveTextRevealStore.shared

    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    var body: some View {
        ItemRow(tint: primaryTagColor, opacity: 0.025, isSelecting: isSelecting, isSelected: isSelected, dragID: clip.id.uuidString) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    imageThumbnail
                    AppListRowHeader(
                        systemImage: clip.type.icon,
                        color: primaryTagColor,
                        title: displayTitle,
                        subtitle: compact || isExpanded ? nil : displaySubtitle,
                        metadata: rowMetadata,
                        lineLimit: compact ? 1 : 2,
                        pinned: clip.isPinned,
                        date: clip.updatedAt,
                        dateSuffix: " ago"
                    )
                }

                if isExpanded {
                    expandedContent
                } else if !clip.tags.isEmpty {
                    rowFooter
                }
            }
        }
        .onTapGesture(perform: primaryAction)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .leading) {
            AppSwipeIconButton(
                systemImage: clip.isPinned ? "pin.slash" : "pin",
                tint: .orange,
                accessibilityLabel: clip.isPinned ? "Unpin" : "Pin"
            ) {
                ClipActionService.togglePin(clip)
            }
        }
        .swipeActions(edge: .trailing) {
            AppSwipeIconButton(systemImage: "trash", role: .destructive, accessibilityLabel: "Delete") {
                ClipActionService.softDelete(clip)
            }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { ClipActionService.copy(clip) }
                .disabled(!clipboardAccessEnabled)
            if ClipActionService.openableURL(for: clip) != nil {
                Button("Open Link", systemImage: "safari") { ClipActionService.openURL(for: clip) }
            }
            if clip.isPrivateContent || ClipClassificationService.canMarkSensitiveMarkdown(in: clip.content) {
                Button(clip.isPrivateContent ? "Unmark Sensitive" : "Mark Sensitive",
                       systemImage: clip.isPrivateContent ? "lock.open" : "lock") {
                    ClipActionService.toggleSensitive(clip)
                }
            }
            Button("Add to Canvas", systemImage: "square.and.arrow.down") { addToCanvas() }
                .disabled(activeWorkspace == nil)
            Button(clip.isPinned ? "Unpin" : "Pin",
                   systemImage: clip.isPinned ? "pin.slash" : "pin") { ClipActionService.togglePin(clip) }
            if let onDetails {
                Button("Details", systemImage: "info.circle", action: onDetails)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { ClipActionService.softDelete(clip) }
        }
    }

    // MARK: - Private

    private func primaryAction() {
        if isSelecting { onSelect?() }
        else if let onPrimaryAction { onPrimaryAction() }
        else { _ = ClipActionService.copy(clip) }
    }

    private var primaryTagColor: Color { clip.primaryDisplayColor }
    private var activeWorkspace: Workspace? { workspaces.first(where: \.isActive) ?? workspaces.first }
    private var displayPreview: String { clip.displayPreview(isRevealed: false) }
    private var plainDisplayPreview: String { Self.plainRowPreview(from: displayPreview, fallback: ClipTag.builtInName(for: clip.type)) }
    private var displayTitle: String {
        plainDisplayPreview
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? ClipTag.builtInName(for: clip.type)
    }
    private var displaySubtitle: String? {
        let lines = plainDisplayPreview
            .components(separatedBy: .newlines)
            .dropFirst()
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return lines.nilIfEmpty
    }
    private func addToCanvas() { activeWorkspace?.placeDuplicate(of: clip, in: context) }

    private var rowMetadata: [AppListRowMetadata] {
        var metadata: [AppListRowMetadata] = []
        if clip.type == .image, let bytes = clip.imageData?.count {
            metadata.append(AppListRowMetadata("externaldrive", value: ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)))
        } else {
            metadata.append(AppListRowMetadata("character.cursor.ibeam", value: "\(clip.content.count)", monospaced: true))
        }
        if clip.isPrivateContent {
            metadata.append(AppListRowMetadata("lock.fill", value: "Sensitive"))
        }
        return metadata
    }

    @ViewBuilder
    private var imageThumbnail: some View {
        if clip.type == .image, let data = clip.imageData, let image = PlatformImage(data: data) {
            #if canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: compact ? 52 : 62, height: compact ? 52 : 62)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            #elseif canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: compact ? 52 : 62, height: compact ? 52 : 62)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            #endif
        }
    }

    private var rowFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            TagPillRow(tags: Array(clip.tags), limit: 3, size: compact ? .compact : .regular)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .opacity(0.42)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                MarkdownPreview(
                    text: displayPreview,
                    revealedSensitiveParts: revealStore.revealedPartIDs,
                    onSensitivePartTapped: revealStore.toggle
                )
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.86))
                .lineLimit(18)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !clip.tags.isEmpty {
                    TagPillRow(tags: Array(clip.tags), limit: 6, size: .regular)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            }
        }
        .padding(.top, 1)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity
        ))
    }

    private static func plainRowPreview(from text: String, fallback: String) -> String {
        let markerPattern = #"^\s{0,3}(?:[-*+]|\d+\.|\[\s?\]|\[x\])\s+"#
        let lines = text
            .components(separatedBy: .newlines)
            .map { line in
                line.replacingOccurrences(of: markerPattern, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^\s{0,3}>\s?"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n").nilIfEmpty ?? fallback
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
