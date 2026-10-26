import Foundation

/// What the Mac is mostly used for. A user can pick more than one.
public enum UsageProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case general
    case office
    case developer
    case creative
    case gamer

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "Everyday Use"
        case .office: return "Office & School"
        case .developer: return "Development"
        case .creative: return "Creative Work"
        case .gamer: return "Gaming"
        }
    }

    public var summary: String {
        switch self {
        case .general: return "Browsing, email, photos and media."
        case .office: return "Documents, meetings and chat apps."
        case .developer: return "Xcode, editors, package managers."
        case .creative: return "Video, photo and audio editing."
        case .gamer: return "Steam and other game launchers."
        }
    }

    public var symbolName: String {
        switch self {
        case .general: return "house"
        case .office: return "doc.text"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .creative: return "camera.aperture"
        case .gamer: return "gamecontroller"
        }
    }

    /// The category of data this profile's own tools produce. Those files are treated carefully because
    /// the user is actively relying on them; everyone else can clean them aggressively.
    public var focusCategory: RuleCategory? {
        switch self {
        case .developer: return .developer
        case .creative: return .creative
        case .gamer: return .gaming
        case .general, .office: return nil
        }
    }

    /// Apps not opened for this long are suggested for removal. People with large professional
    /// toolkits open some tools rarely, so they get a longer window.
    public var unusedAppThresholdDays: Int {
        switch self {
        case .general, .office: return 90
        case .developer, .creative, .gamer: return 180
        }
    }
}

/// How a rule is treated for the selected profiles.
public enum PolicyMode: String, Codable, Sendable, Comparable {
    /// Shorter age limit; pre-selected even when the data is costly to rebuild.
    case aggressive
    /// Default age limit; pre-selected unless the data is costly to rebuild.
    case standard
    /// Longer age limit; pre-selected only when trivially rebuilt.
    case careful
    /// Never scanned or offered.
    case protect

    private var conservativeness: Int {
        switch self {
        case .aggressive: return 0
        case .standard: return 1
        case .careful: return 2
        case .protect: return 3
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.conservativeness < rhs.conservativeness }
}
