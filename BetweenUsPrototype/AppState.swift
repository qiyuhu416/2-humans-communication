import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var stage: AppStage = .perspective
    @Published var entryMode: ReflectionEntryMode = .concreteMoment
    @Published var feeling: String = ""
    @Published var sharedExperiment: String = ""

    @Published var qiyuChoiceID: String?
    @Published var samarPredictionID: String?
    @Published var qiyuLocked = false
    @Published var samarLocked = false
    @Published var currentRoundIndex = 0
    @Published var showDiscussionQuestions = false
    @Published var roundRecords: [RoundAnswerRecord] = []
    @Published var savedSessions: [SavedSession] = []
    @Published var selectedSessionID: UUID?

    private let historyKey = "between-us.saved-sessions"

    init() {
        loadHistory()
    }

    let rounds: [ScenarioRound] = [
        ScenarioRound(
            id: "advance-notice",
            opening: "Samar works about 12 hours each day this week. Saturday afternoon eventually becomes available for the same hike.",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which week would you choose?",
            samarPrompt: "Which week would Qiyu choose?",
            scenarios: [
                Scenario(
                    id: "monday-plan",
                    title: "Planned Monday",
                    summary: "The Saturday hike is planned Monday.",
                    body: "On Monday, Samar sends:\n\n“Could we keep Saturday afternoon for our hike?”\n\nThey go hiking Saturday afternoon."
                ),
                Scenario(
                    id: "friday-plan",
                    title: "Planned Friday",
                    summary: "The same Saturday hike is planned Friday.",
                    body: "On Friday, Samar sends:\n\n“Could we go hiking Saturday afternoon?”\n\nThey go hiking Saturday afternoon."
                )
            ],
            discussionQuestions: [
                "By which day would having the plan begin to change how Qiyu experiences the week?",
                "If both hikes happen, what is different about knowing on Monday?",
                "Would Tuesday or Wednesday feel meaningfully different from Friday?"
            ]
        ),
        ScenarioRound(
            id: "who-asks-first",
            opening: "It is Monday. The same Saturday afternoon hike is available in both versions.",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which invitation would you choose?",
            samarPrompt: "Which invitation would Qiyu choose?",
            scenarios: [
                Scenario(
                    id: "qiyu-asks",
                    title: "Qiyu asks first",
                    summary: "Qiyu begins the conversation.",
                    body: "On Monday, Qiyu sends:\n\n“When are you free this weekend?”\n\nSamar replies:\n\n“Saturday afternoon? We could hike.”"
                ),
                Scenario(
                    id: "samar-asks",
                    title: "Samar asks first",
                    summary: "Samar begins the conversation.",
                    body: "On Monday, before Qiyu asks, Samar sends:\n\n“Are you free Saturday afternoon? We could hike.”"
                )
            ],
            discussionQuestions: [
                "If the same hike happens either way, what changes when Samar asks first?",
                "Does Qiyu want Samar to choose the activity, or simply begin the conversation?",
                "How often would Samar starting the plan make a noticeable difference?"
            ]
        ),
        ScenarioRound(
            id: "busy-week-boundary",
            opening: "On Monday, Samar does not know whether work will end at 6 p.m. or 10 p.m. later this week.",
            focusPerspective: .samar,
            qiyuPrompt: "Which one does Qiyu think Samar could repeat?",
            samarPrompt: "Which one could Samar realistically repeat during most busy weeks?",
            scenarios: [
                Scenario(
                    id: "early-tentative",
                    title: "Tentative on Monday",
                    summary: "A possible time is named Monday.",
                    body: "On Monday, Samar says:\n\n“Saturday afternoon might work. I’ll confirm by Thursday.”\n\nOn Thursday, he confirms or suggests another time."
                ),
                Scenario(
                    id: "confirm-thursday",
                    title: "Confirmed on Thursday",
                    summary: "No possible time is named until Thursday.",
                    body: "Samar waits until Thursday, checks his work schedule, and then sends one confirmed time for the weekend."
                )
            ],
            discussionQuestions: [
                "Which part of the other option would be difficult for Samar to repeat every week?",
                "Can Samar suggest a possible time before he can confirm it?",
                "What follow-up day would be realistic during a twelve-hour work week?"
            ]
        )
    ]

    var currentRound: ScenarioRound {
        rounds[min(currentRoundIndex, rounds.count - 1)]
    }

    var canReveal: Bool { qiyuLocked && samarLocked }

    var answersMatch: Bool {
        guard let qiyuChoiceID, let samarPredictionID else { return false }
        return qiyuChoiceID == samarPredictionID
    }

    func startQiyuFlow() {
        stage = savedSessions.isEmpty ? .entryChoice : .qiyuHome
    }
    func startSamarFlow() { stage = .samarPlaceholder }

    var selectedSession: SavedSession? {
        if let selectedSessionID,
           let selected = savedSessions.first(where: { $0.id == selectedSessionID }) {
            return selected
        }
        return savedSessions.first
    }

    func openSession(_ session: SavedSession) {
        selectedSessionID = session.id
        stage = .summary
    }

    func startNextRound() {
        recordCurrentRoundIfNeeded()
        guard currentRoundIndex + 1 < rounds.count else { return }
        currentRoundIndex += 1
        clearRoundAnswers()
        stage = .roundIntro
    }

    func resetSession() {
        stage = .perspective
        feeling = ""
        sharedExperiment = ""
        currentRoundIndex = 0
        roundRecords = []
        clearRoundAnswers()
    }

    func startNewReflection() {
        feeling = ""
        sharedExperiment = ""
        currentRoundIndex = 0
        roundRecords = []
        clearRoundAnswers()
        stage = .entryChoice
    }

    func recordCurrentRoundIfNeeded() {
        guard let qiyuChoiceID,
              let samarPredictionID,
              let qiyuChoice = currentRound.scenarios.first(where: { $0.id == qiyuChoiceID }),
              let samarPrediction = currentRound.scenarios.first(where: { $0.id == samarPredictionID })
        else { return }

        let record = RoundAnswerRecord(
            id: currentRound.id,
            opening: currentRound.opening,
            qiyuChoice: qiyuChoice,
            samarPrediction: samarPrediction,
            focusPerspective: currentRound.focusPerspective
        )

        if let index = roundRecords.firstIndex(where: { $0.id == record.id }) {
            roundRecords[index] = record
        } else {
            roundRecords.append(record)
        }
    }

    func finishSession() {
        recordCurrentRoundIfNeeded()
        guard !roundRecords.isEmpty else {
            stage = .perspective
            return
        }

        let session = SavedSession(
            id: UUID(),
            createdAt: Date(),
            feeling: feeling,
            answers: roundRecords,
            experiment: sharedExperiment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : sharedExperiment
        )
        savedSessions.insert(session, at: 0)
        selectedSessionID = session.id
        persistHistory()
        stage = .summary
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(savedSessions) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let sessions = try? JSONDecoder().decode([SavedSession].self, from: data)
        else { return }
        savedSessions = sessions
    }

    private func clearRoundAnswers() {
        qiyuChoiceID = nil
        samarPredictionID = nil
        qiyuLocked = false
        samarLocked = false
        showDiscussionQuestions = false
    }
}

protocol DiscussionQuestionProviding {
    func questions(for round: ScenarioRound, selectedScenarioID: String?) -> [String]
}

struct LocalDiscussionQuestionProvider: DiscussionQuestionProviding {
    func questions(for round: ScenarioRound, selectedScenarioID: String?) -> [String] {
        round.discussionQuestions
    }
}
