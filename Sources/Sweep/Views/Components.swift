import SwiftUI
import SweepCore

struct Checkbox: View {
    let state: AppModel.SelectionState
    let action: @MainActor () -> Void

    init(state: AppModel.SelectionState, action: @escaping @MainActor () -> Void) {
        self.state = state
        self.action = action
    }

    init(isOn: Bool, action: @escaping @MainActor () -> Void) {
        self.init(state: isOn ? .all : .none, action: action)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(state == .none ? Color.secondary : Color.accentColor)
                .imageScale(.large)
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch state {
        case .all: return "checkmark.square.fill"
        case .some: return "minus.square.fill"
        case .none: return "square"
        }
    }
}

struct Tag: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

/// One file or folder in a result list.
struct ItemRow: View {
    let item: ScanItem
    let isSelected: Bool
    let toggle: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Checkbox(isOn: isSelected, action: toggle)
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let running = item.inUseBy {
                        Tag(text: "\(SystemIntegration.appName(for: running) ?? "App") is open", color: .orange)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Text(ByteFormat.string(item.bytes))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .help(item.location)
        .contextMenu {
            Button("Show in Finder") { SystemIntegration.revealInFinder(item.url) }
        }
    }

    private var ownerAppURL: URL? {
        item.ownerBundleIDs.lazy.compactMap { SystemIntegration.appURL(for: $0) }.first
    }

    private var title: String {
        // "com.spotify.client" is more useful as "Spotify".
        if BundleID.looksLikeBundleID(item.displayName), let url = ownerAppURL {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return item.displayName
    }

    private var subtitle: String {
        var parts = [item.location]
        if let modified = item.lastModified {
            parts.append("used \(DateFormat.relative(modified))")
        }
        return parts.joined(separator: " · ")
    }

    private var icon: NSImage {
        if let url = ownerAppURL, BundleID.looksLikeBundleID(item.displayName) {
            return SystemIntegration.icon(for: url)
        }
        return SystemIntegration.icon(for: item.url)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FullDiskAccessBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Some folders couldn't be read")
                    .font(.callout.weight(.semibold))
                Text("Grant Full Disk Access so Sweep can include the Trash, Mail downloads and app containers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Privacy Settings") { SystemIntegration.openFullDiskAccessSettings() }
                    .buttonStyle(BubbleButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
