import Foundation

struct Scenario: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let summary: String
    let body: String
}

struct SuggestedReading: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let source: String
    let takeaway: String
    let url: String
}

struct ScenarioRound: Identifiable, Hashable, Codable {
    let id: String
    let opening: String
    let openingQuestion: String
    let currentDayIndex: Int
    let targetDayIndex: Int
    let timelineTargetLabel: String
    let focusPerspective: Perspective
    let qiyuPrompt: String
    let samarPrompt: String
    let testedVariableLabel: String
    let testVariable: String
    let potentialVariables: [String]
    let heldConstant: [String]
    let rationale: String
    let scenarios: [Scenario]
    let discussionQuestions: [String]
    let suggestedReadings: [SuggestedReading]
}

struct RoundAnswerRecord: Identifiable, Hashable, Codable {
    let id: String
    let opening: String
    let qiyuChoice: Scenario
    let samarPrediction: Scenario
    let focusPerspective: Perspective?

    var matches: Bool { qiyuChoice.id == samarPrediction.id }
    var focus: Perspective { focusPerspective ?? .qiyu }
}

struct SavedSession: Identifiable, Hashable, Codable {
    let id: UUID
    let createdAt: Date
    let feeling: String
    let answers: [RoundAnswerRecord]
    let experiment: String?
    let receiver: Perspective?
}

enum ProfileEvidenceSource: String, Codable, Hashable {
    case selfConfirmed
    case partnerObserved
    case aiHypothesis

    var label: String {
        switch self {
        case .selfConfirmed: return "Confirmed by me"
        case .partnerObserved: return "Observed by partner"
        case .aiHypothesis: return "To explore"
        }
    }
}

enum ProfileInsightKind: String, Codable, Hashable {
    case connection
    case constraint
    case communication
    case sustainableAction

    var label: String {
        switch self {
        case .connection: return "Moments that work"
        case .constraint: return "Real constraints"
        case .communication: return "How we communicate"
        case .sustainableAction: return "Repeatable actions"
        }
    }
}

struct ProfileInsight: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: ProfileInsightKind
    var statement: String
    var evidence: String
    var source: ProfileEvidenceSource
}

struct PersonProfile: Identifiable, Hashable, Codable {
    let id: Perspective
    var name: String
    var insights: [ProfileInsight]
}

struct ProfileInsightSuggestion: Hashable {
    let person: Perspective
    let kind: ProfileInsightKind
    let statement: String
    let evidence: String
}

struct PersonalizationContext: Codable {
    let people: [PersonProfile]
    let rules: [String]
}

struct ScenarioGenerationRequest: Codable {
    let entryMode: String
    let userText: String
    let profile: PersonalizationContext
}

enum Perspective: String, Codable, Hashable {
    case qiyu = "Qiyu"
    case samar = "Samar"

    var partner: Perspective {
        self == .qiyu ? .samar : .qiyu
    }
}

enum ReflectionEntryMode: String {
    case concreteMoment
    case connectionQuestion
}

enum ScenarioSourceMode: String, CaseIterable, Identifiable {
    case curated = "Hard-coded"
    case adaptive = "AI"

    var id: String { rawValue }
}

enum AppStage {
    case perspective
    case qiyuHome
    case entryChoice
    case qiyuFeeling
    case conversationGuide
    case roundIntro
    case qiyuScenario
    case reveal
    case coDesign
    case summary
    case profiles
    case samarPlaceholder
}
