import Foundation

/// Represents a binary like reaction toggled by the user.
public enum OAReaction: Equatable, Sendable {
    case none
    case heart

    /// Returns the opposite reaction for tap toggling.
    public var toggled: OAReaction {
        switch self {
        case .none: return .heart
        case .heart: return .none
        }
    }
}
