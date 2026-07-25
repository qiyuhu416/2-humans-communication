import Foundation

struct Scenario: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let summary: String
    let body: String
}

struct ScenarioRound: Identifiable, Hashable, Codable {
    let id: String
    let opening: String
    let focusPerspective: Perspective
    let qiyuPrompt: String
    let samarPrompt: String
    let scenarios: [Scenario]
    let discussionQuestions: [String]
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
}

enum Perspective: String, Codable, Hashable {
    case qiyu = "Qiyu"
    case samar = "Samar"
}

enum ReflectionEntryMode: String {
    case concreteMoment
    case connectionQuestion
}

enum AppStage {
    case perspective
    case qiyuHome
    case entryChoice
    case qiyuFeeling
    case roundIntro
    case qiyuScenario
    case reveal
    case coDesign
    case summary
    case samarPlaceholder
}
