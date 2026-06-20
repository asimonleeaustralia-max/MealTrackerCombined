import Foundation

enum DataSharingPreference: String, CaseIterable, Identifiable {
    case `public`
    case `private`

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .public: return NSLocalizedString("data_sharing.public", comment: "")
        case .private: return NSLocalizedString("data_sharing.private", comment: "")
        }
    }

    var explanation: String {
        switch self {
        case .public:
            return NSLocalizedString("data_sharing.public_explanation", comment: "")
        case .private:
            return NSLocalizedString("data_sharing.private_explanation", comment: "")
        }
    }
}

enum AIFeedbackSeverity: String, CaseIterable, Identifiable {
    case kind
    case balanced
    case bootCamp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kind:
            return NSLocalizedString("ai_feedback_severity.kind", comment: "")
        case .balanced:
            return NSLocalizedString("ai_feedback_severity.balanced", comment: "")
        case .bootCamp:
            return NSLocalizedString("ai_feedback_severity.boot_camp", comment: "")
        }
    }
}

