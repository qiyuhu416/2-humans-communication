import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol ScenarioGenerationProvider {
    var availabilityDescription: String { get }
    var isAvailable: Bool { get }

    func generate(
        request: ScenarioGenerationRequest,
        receiver: Perspective
    ) async throws -> [ScenarioRound]
}

enum ScenarioGenerationError: LocalizedError {
    case operatingSystemTooOld
    case modelUnavailable(String)
    case cloudNotConfigured
    case cloudError(String)
    case invalidScenarios

    var errorDescription: String? {
        switch self {
        case .operatingSystemTooOld:
            return "On-device AI requires iOS 26 or later."
        case .modelUnavailable(let reason):
            return reason
        case .cloudNotConfigured:
            return "Add the cloud generator URL in the AI tab."
        case .cloudError(let message):
            return message
        case .invalidScenarios:
            return "The on-device model did not create a usable comparison. Try a shorter, more concrete question."
        }
    }
}

struct CloudScenarioService: ScenarioGenerationProvider {
    private struct CloudRequest: Encodable {
        let request: ScenarioGenerationRequest
        let receiver: Perspective
    }

    private struct CloudResponse: Decodable {
        let rounds: [ScenarioRound]
    }

    let endpoint: String

    var isAvailable: Bool {
        guard let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased()
        else { return false }
        return scheme == "https" || scheme == "http"
    }

    var availabilityDescription: String {
        isAvailable ? "Cloud generator configured" : "Add a backend URL"
    }

    func generate(
        request: ScenarioGenerationRequest,
        receiver: Perspective
    ) async throws -> [ScenarioRound] {
        guard let url = URL(string: endpoint), isAvailable else {
            throw ScenarioGenerationError.cloudNotConfigured
        }

        var networkRequest = URLRequest(url: url.appendingPathComponent("generate"))
        networkRequest.httpMethod = "POST"
        networkRequest.timeoutInterval = 65
        networkRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        networkRequest.httpBody = try JSONEncoder().encode(
            CloudRequest(request: request, receiver: receiver)
        )

        let (data, response) = try await URLSession.shared.data(for: networkRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ScenarioGenerationError.cloudError("The cloud generator did not return an HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = object?["error"] as? String
            throw ScenarioGenerationError.cloudError(
                message ?? "Cloud generation failed with HTTP \(http.statusCode)."
            )
        }

        let payload = try JSONDecoder().decode(CloudResponse.self, from: data)
        guard !payload.rounds.isEmpty,
              payload.rounds.allSatisfy({ $0.scenarios.count == 2 })
        else {
            throw ScenarioGenerationError.invalidScenarios
        }
        return payload.rounds
    }
}

struct OnDeviceScenarioService: ScenarioGenerationProvider {
    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            return SystemLanguageModel.default.isAvailable
            #else
            return false
            #endif
        }
        return false
        #endif
    }

    var availabilityDescription: String {
        #if targetEnvironment(simulator)
        return "The iOS Simulator does not provide the Apple Intelligence on-device model. Run the app on a supported physical iPhone."
        #else
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Ready on this device"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence to use on-device generation."
            case .unavailable(.deviceNotEligible):
                return "This device does not support Apple Intelligence."
            case .unavailable(.modelNotReady):
                return "The on-device model is still downloading."
            @unknown default:
                return "The on-device model is not available right now."
            }
            #else
            return "Foundation Models is not included in this SDK."
            #endif
        }
        return "Requires iOS 26 or later"
        #endif
    }

    func generate(
        request: ScenarioGenerationRequest,
        receiver: Perspective
    ) async throws -> [ScenarioRound] {
        guard #available(iOS 26.0, *) else {
            throw ScenarioGenerationError.operatingSystemTooOld
        }

        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.isAvailable else {
            throw ScenarioGenerationError.modelUnavailable(availabilityDescription)
        }
        return try await generateWithAppleModel(request: request, receiver: receiver)
        #else
        throw ScenarioGenerationError.modelUnavailable(availabilityDescription)
        #endif
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private struct GeneratedScenarioOption: Decodable {
    var title: String
    var summary: String
    var body: String
}

@available(iOS 26.0, *)
private struct GeneratedScenarioRound: Decodable {
    var opening: String
    var openingQuestion: String
    var testedVariableLabel: String
    var testVariable: String
    var potentialVariables: [String]
    var heldConstant: [String]
    var rationale: String
    var optionA: GeneratedScenarioOption
    var optionB: GeneratedScenarioOption
    var discussionQuestions: [String]
}

@available(iOS 26.0, *)
private struct GeneratedScenarioSet: Decodable {
    var rounds: [GeneratedScenarioRound]
}

@available(iOS 26.0, *)
private extension OnDeviceScenarioService {
    func generateWithAppleModel(
        request: ScenarioGenerationRequest,
        receiver: Perspective
    ) async throws -> [ScenarioRound] {
        let actor = receiver.partner
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let context = String(decoding: try encoder.encode(request), as: UTF8.self)

        let session = LanguageModelSession(instructions: """
        You create concrete, neutral conversation references for two people.
        Do not diagnose either person, infer hidden feelings, or decide which behavior is better.
        Change one observable behavior at a time while holding the rest of the moment constant.
        Write casual, specific scenes using actions, words, timing, and real constraints.
        """)

        let response = try await session.respond(
            to: """
            Create exactly three comparison rounds for \(receiver.rawValue) and \(actor.rawValue).

            \(receiver.rawValue) will choose what would feel good to receive.
            \(actor.rawValue) will independently choose what they could comfortably do.

            For every round:
            - Write a short opening that places both people in one everyday moment.
            - Give exactly two plausible options. Each option is a short narrative showing what \(actor.rawValue) says or does.
            - Keep workload, timing, and surrounding facts the same; vary one behavior only.
            - Neither option should sound more caring, mature, or correct.
            - Do not claim either person wants to meet, is free, is thinking about the relationship, or feels something unless the input says so.
            - Use 3–5 short potential-variable labels, 2–4 held-constant facts, and 2–3 concrete follow-up questions.
            - Order the rounds from closest to the typed concern to an adjacent uncertainty.

            Return only valid JSON in this shape:
            {
              "rounds": [{
                "opening": "string",
                "openingQuestion": "string",
                "testedVariableLabel": "string",
                "testVariable": "string",
                "potentialVariables": ["string"],
                "heldConstant": ["string"],
                "rationale": "string",
                "optionA": {"title":"string","summary":"string","body":"string"},
                "optionB": {"title":"string","summary":"string","body":"string"},
                "discussionQuestions": ["string"]
              }]
            }

            User input and saved profile context:
            \(context)
            """
        )

        var rawText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawText.hasPrefix("```") {
            rawText = rawText
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = rawText.data(using: .utf8),
              let payload = try? JSONDecoder().decode(GeneratedScenarioSet.self, from: data)
        else {
            throw ScenarioGenerationError.invalidScenarios
        }

        let generated = Array(payload.rounds.prefix(3))
        guard generated.count == 3 else {
            throw ScenarioGenerationError.invalidScenarios
        }

        return generated.enumerated().map { index, draft in
            let baseID = "on-device-\(index)-\(UUID().uuidString.lowercased())"
            return ScenarioRound(
                id: baseID,
                opening: draft.opening,
                openingQuestion: draft.openingQuestion,
                currentDayIndex: 0,
                targetDayIndex: 0,
                timelineTargetLabel: "",
                focusPerspective: receiver,
                qiyuPrompt: receiver == .qiyu
                    ? "Which would feel good for Qiyu to receive?"
                    : "Which could Qiyu comfortably do?",
                samarPrompt: receiver == .samar
                    ? "Which would feel good for Samar to receive?"
                    : "Which could Samar comfortably do?",
                testedVariableLabel: draft.testedVariableLabel,
                testVariable: draft.testVariable,
                potentialVariables: Array(draft.potentialVariables.prefix(5)),
                heldConstant: Array(draft.heldConstant.prefix(4)),
                rationale: draft.rationale,
                scenarios: [
                    Scenario(
                        id: "\(baseID)-a",
                        title: draft.optionA.title,
                        summary: draft.optionA.summary,
                        body: draft.optionA.body
                    ),
                    Scenario(
                        id: "\(baseID)-b",
                        title: draft.optionB.title,
                        summary: draft.optionB.summary,
                        body: draft.optionB.body
                    )
                ],
                discussionQuestions: Array(draft.discussionQuestions.prefix(3)),
                suggestedReadings: []
            )
        }
    }
}
#endif

/// A deterministic first implementation of the adaptive scenario planner.
///
/// It deliberately keeps generation separate from presentation:
/// 1. extract behavioral themes from the user's own words,
/// 2. rank controlled vignette rounds by relevance,
/// 3. move a bridge question forward when two answers reveal a gap.
///
/// A server or on-device language model can later conform to the same interface
/// and return newly written `ScenarioRound` values.
struct LocalAdaptiveScenarioEngine {
    private struct Aspect {
        let roundID: String
        let keywords: [String]
        let basePriority: Int
    }

    private let aspects: [Aspect] = [
        Aspect(
            roundID: "advance-notice",
            keywords: [
                "plan", "planning", "weekend", "availability", "unclear", "follow up",
                "check again", "to-do", "schedule", "meet",
                "见", "计划", "周末", "时间", "安排", "不确定", "再告诉"
            ],
            basePriority: 8
        ),
        Aspect(
            roundID: "who-asks-first",
            keywords: ["initiate", "initiative", "ask", "reach out", "主动", "邀请", "联系"],
            basePriority: 7
        ),
        Aspect(
            roundID: "busy-week-boundary",
            keywords: [
                "busy", "work", "uncertain", "unpredictable", "tentative", "confirm", "schedule",
                "忙", "工作", "不确定", "暂定", "确认", "加班"
            ],
            basePriority: 6
        ),
        Aspect(
            roundID: "sharing-small-joy",
            keywords: [
                "share", "text", "photo", "sunset", "moment", "reply", "experience",
                "thought of you", "attention",
                "分享", "短信", "照片", "夕阳", "回应", "想到你", "感受"
            ],
            basePriority: 5
        ),
        Aspect(
            roundID: "busy-day-update",
            keywords: [
                "disappear", "quiet", "reply", "update", "message", "busy", "reconnect",
                "after work", "unavailable",
                "消失", "没消息", "回复", "忙", "下班", "忙完"
            ],
            basePriority: 5
        ),
        Aspect(
            roundID: "support-after-hard-day",
            keywords: ["tired", "stress", "hard day", "support", "listen", "累", "压力", "难受", "倾听", "支持"],
            basePriority: 4
        ),
        Aspect(
            roundID: "conflict-first-step",
            keywords: ["hurt", "conflict", "argument", "disappointed", "repair", "伤心", "冲突", "吵架", "失望"],
            basePriority: 4
        ),
        Aspect(
            roundID: "pause-and-return",
            keywords: ["pause", "sleep", "late", "overwhelmed", "space", "暂停", "睡觉", "太晚", "空间"],
            basePriority: 3
        ),
        Aspect(
            roundID: "shared-time-rhythm",
            keywords: ["time together", "independent", "whole day", "space", "一起", "独立", "整天", "私人时间"],
            basePriority: 3
        ),
        Aspect(
            roundID: "plan-changes",
            keywords: ["cancel", "change", "alternative", "reschedule", "取消", "改计划", "改时间"],
            basePriority: 4
        ),
        Aspect(
            roundID: "response-timing",
            keywords: ["response", "reply", "break", "after work", "回复", "休息", "下班"],
            basePriority: 3
        ),
        Aspect(
            roundID: "good-news",
            keywords: ["good news", "celebrate", "approved", "achievement", "好消息", "庆祝", "通过了"],
            basePriority: 3
        ),
        Aspect(
            roundID: "physical-reconnection",
            keywords: ["hug", "touch", "physical", "reconnect", "拥抱", "牵手", "身体接触"],
            basePriority: 2
        ),
        Aspect(
            roundID: "repair-next-step",
            keywords: ["repair", "understand", "solution", "next time", "修复", "理解", "解决", "下次"],
            basePriority: 3
        )
    ]

    func generate(
        from source: [ScenarioRound],
        userText: String,
        profile: PersonalizationContext,
        receiver: Perspective
    ) -> [ScenarioRound] {
        if receiver == .samar {
            return receiverLedRounds(
                receiver: receiver,
                actor: receiver.partner,
                userText: userText
            )
        }

        let normalized = userText.lowercased()
        let profileText = profile.people
            .flatMap(\.insights)
            .map { "\($0.statement) \($0.evidence)" }
            .joined(separator: " ")
            .lowercased()

        let rankedIDs = aspects
            .map { aspect -> (String, Int) in
                let directMatches = aspect.keywords.filter { normalized.contains($0) }.count
                let profileMatches = aspect.keywords.filter { profileText.contains($0) }.count
                let score = directMatches * 12 + min(profileMatches, 3) * 2 + aspect.basePriority
                return (aspect.roundID, score)
            }
            .sorted {
                if $0.1 == $1.1 { return $0.0 < $1.0 }
                return $0.1 > $1.1
            }
            .map(\.0)

        let byID = Dictionary(uniqueKeysWithValues: source.map { ($0.id, $0) })
        return rankedIDs.compactMap { byID[$0] }
    }

    private func receiverLedRounds(
        receiver: Perspective,
        actor: Perspective,
        userText: String
    ) -> [ScenarioRound] {
        let all = [
            coordinationLoadRound(receiver: receiver, actor: actor),
            workBoundaryRound(receiver: receiver, actor: actor),
            recognitionRound(receiver: receiver, actor: actor),
            supportRound(receiver: receiver, actor: actor),
            planningOwnershipRound(receiver: receiver, actor: actor)
        ]

        let normalized = userText.lowercased()
        let priorities: [(id: String, terms: [String])] = [
            (
                "generated-coordination-load",
                [
                    "manage", "relationship", "decision", "unclear schedule", "do not know my schedule",
                    "what would help both", "too much to manage",
                    "安排", "管理", "关系", "决定", "不知道时间", "不确定"
                ]
            ),
            (
                "generated-work-boundary",
                [
                    "work", "busy", "tired", "meeting", "focused work", "ask for space",
                    "taking most of my energy", "without creating more confusion",
                    "工作", "忙", "累", "会议", "专心工作", "需要空间"
                ]
            ),
            (
                "generated-recognition",
                [
                    "effort", "understand", "appreciate", "energy", "carrying",
                    "压力", "辛苦", "理解", "精力"
                ]
            ),
            (
                "generated-support",
                [
                    "support", "help", "overwhelmed", "response from", "actually help",
                    "feel tired", "what kind of response",
                    "支持", "帮助", "撑不住", "什么回应", "太累"
                ]
            ),
            (
                "generated-planning-ownership",
                [
                    "weekend", "schedule", "initiate", "sharing the planning", "parts of making plans",
                    "each take on", "who plans", "making plans",
                    "周末", "时间", "主动", "分担计划", "谁来计划"
                ]
            )
        ]

        let scores = Dictionary(uniqueKeysWithValues: priorities.map { item in
            (item.id, item.terms.filter { normalized.contains($0) }.count)
        })

        return all.sorted {
            let left = scores[$0.id, default: 0]
            let right = scores[$1.id, default: 0]
            if left == right { return $0.id < $1.id }
            return left > right
        }
    }

    private func coordinationLoadRound(
        receiver: Perspective,
        actor: Perspective
    ) -> ScenarioRound {
        ScenarioRound(
            id: "generated-coordination-load",
            opening: "It is Friday at 5:30 p.m. \(receiver.rawValue) still has two unfinished work tasks and cannot yet tell what part of the weekend will be open.",
            openingQuestion: "\(actor.rawValue) could respond to the uncertainty in different ways.",
            currentDayIndex: 4,
            targetDayIndex: 5,
            timelineTargetLabel: "",
            focusPerspective: receiver,
            qiyuPrompt: prompt(for: .qiyu, receiver: receiver),
            samarPrompt: prompt(for: .samar, receiver: receiver),
            testedVariableLabel: "How coordination is shared",
            testVariable: "Whether the partner proposes options, sets a later decision point, or leaves initiation with the busy person.",
            potentialVariables: ["Propose options", "Decision point", "Leave it open", "Work uncertainty"],
            heldConstant: ["Friday at 5:30 p.m.", "The same unfinished work", "Weekend availability is unknown"],
            rationale: "The workload remains unchanged. The options vary which piece of relationship coordination \(actor.rawValue) takes on.",
            scenarios: [
                Scenario(
                    id: "coordination-offer-options",
                    title: "Offer two possibilities",
                    summary: "\(actor.rawValue) prepares two options for later.",
                    body: "\(actor.rawValue) texts:\n\n“I can suggest two possible times for the weekend. You can tell me which one works after you finish.”"
                ),
                Scenario(
                    id: "coordination-decision-point",
                    title: "Choose when to decide",
                    summary: "\(actor.rawValue) removes the need to decide now.",
                    body: "\(actor.rawValue) texts:\n\n“You don’t need to decide now. Could you let me know by noon tomorrow whether you want to make a plan?”"
                ),
                Scenario(
                    id: "coordination-leave-open",
                    title: "Leave the weekend open",
                    summary: "\(actor.rawValue) waits for \(receiver.rawValue) to know more.",
                    body: "\(actor.rawValue) does not ask for a weekend decision that evening. On Saturday, \(actor.rawValue) waits for \(receiver.rawValue) to bring it up."
                )
            ],
            discussionQuestions: [
                "Which part would reduce work for \(receiver.rawValue)?",
                "Which part would create more work for \(actor.rawValue)?",
                "Could a smaller combination of two options work for both?"
            ],
            suggestedReadings: []
        )
    }

    private func workBoundaryRound(receiver: Perspective, actor: Perspective) -> ScenarioRound {
        ScenarioRound(
            id: "generated-work-boundary",
            opening: "\(receiver.rawValue) begins a two-hour work block after saying, “I’m tired and need to finish this before I can think about the weekend.”",
            openingQuestion: "\(actor.rawValue) could handle the next two hours in either of these ways.",
            currentDayIndex: 4,
            targetDayIndex: 4,
            timelineTargetLabel: "After work",
            focusPerspective: receiver,
            qiyuPrompt: prompt(for: .qiyu, receiver: receiver),
            samarPrompt: prompt(for: .samar, receiver: receiver),
            testedVariableLabel: "Contact during focused work",
            testVariable: "A quiet work boundary versus one low-demand check-in.",
            potentialVariables: ["No contact", "One check-in", "Response expected", "Work duration"],
            heldConstant: ["The same two-hour work block", "No relationship decision during work"],
            rationale: "Both versions postpone the relationship decision. What changes is whether \(actor.rawValue) sends one message during the work block.",
            scenarios: [
                Scenario(
                    id: "boundary-quiet",
                    title: "Wait until the work block ends",
                    summary: "\(actor.rawValue) does not send another message during the two hours.",
                    body: "\(actor.rawValue) replies:\n\n“Okay. Finish what you need to do. We can talk after.”\n\n\(actor.rawValue) waits for \(receiver.rawValue) to return."
                ),
                Scenario(
                    id: "boundary-checkin",
                    title: "Send one no-reply check-in",
                    summary: "\(actor.rawValue) sends one message without requesting a response.",
                    body: "An hour later, \(actor.rawValue) sends:\n\n“No need to reply—I hope the work is moving along. We can talk when you’re done.”"
                )
            ],
            discussionQuestions: [
                "Does a no-reply message still interrupt the work block?",
                "How should \(receiver.rawValue) signal that the work block has ended?",
                "Would the answer change on a less exhausting day?"
            ],
            suggestedReadings: []
        )
    }

    private func recognitionRound(receiver: Perspective, actor: Perspective) -> ScenarioRound {
        ScenarioRound(
            id: "generated-recognition",
            opening: "After a long workday, \(receiver.rawValue) says, “I feel tired trying to keep up with both work and our relationship.”",
            openingQuestion: "\(actor.rawValue) could place attention on different parts of that sentence.",
            currentDayIndex: 4,
            targetDayIndex: 4,
            timelineTargetLabel: "After work",
            focusPerspective: receiver,
            qiyuPrompt: prompt(for: .qiyu, receiver: receiver),
            samarPrompt: prompt(for: .samar, receiver: receiver),
            testedVariableLabel: "What the response recognizes",
            testVariable: "Effort, current capacity, or a specific responsibility.",
            potentialVariables: ["Effort", "Capacity", "Responsibility", "Advice"],
            heldConstant: ["The same disclosure", "No immediate solution is required"],
            rationale: "The options do not rank care. They test which part of \(receiver.rawValue)’s experience is most useful for \(actor.rawValue) to notice first.",
            scenarios: [
                Scenario(
                    id: "recognize-effort",
                    title: "Recognize the effort",
                    summary: "\(actor.rawValue) notices how much \(receiver.rawValue) is carrying.",
                    body: "\(actor.rawValue) says:\n\n“It sounds like you’ve been putting a lot of energy into keeping both going.”"
                ),
                Scenario(
                    id: "recognize-capacity",
                    title: "Ask about capacity",
                    summary: "\(actor.rawValue) asks what feels manageable now.",
                    body: "\(actor.rawValue) says:\n\n“What part feels manageable right now, and what feels like too much?”"
                ),
                Scenario(
                    id: "recognize-responsibility",
                    title: "Name one responsibility",
                    summary: "\(actor.rawValue) offers to take one task.",
                    body: "\(actor.rawValue) says:\n\n“Would it help if I handled making the next plan?”"
                )
            ],
            discussionQuestions: [
                "What does \(receiver.rawValue) want understood before discussing a solution?",
                "Which offer could \(actor.rawValue) make without overpromising?",
                "Is the tiring part emotional attention, planning, or something else?"
            ],
            suggestedReadings: []
        )
    }

    private func supportRound(receiver: Perspective, actor: Perspective) -> ScenarioRound {
        ScenarioRound(
            id: "generated-support",
            opening: "\(receiver.rawValue) has finished work and has thirty minutes before going home.",
            openingQuestion: "\(actor.rawValue) could offer different kinds of support.",
            currentDayIndex: 4,
            targetDayIndex: 4,
            timelineTargetLabel: "30 minutes",
            focusPerspective: receiver,
            qiyuPrompt: prompt(for: .qiyu, receiver: receiver),
            samarPrompt: prompt(for: .samar, receiver: receiver),
            testedVariableLabel: "Kind of support",
            testVariable: "Listening, practical coordination, or low-demand company.",
            potentialVariables: ["Listening", "Practical help", "Quiet company"],
            heldConstant: ["Thirty minutes", "The workday has ended", "No full relationship solution"],
            rationale: "The available time stays fixed while the form of support changes.",
            scenarios: [
                Scenario(
                    id: "receiver-support-listen",
                    title: "Listen",
                    summary: "\(actor.rawValue) makes room for \(receiver.rawValue) to talk.",
                    body: "\(actor.rawValue) says:\n\n“Tell me which part of today took the most out of you.”"
                ),
                Scenario(
                    id: "receiver-support-plan",
                    title: "Take one planning task",
                    summary: "\(actor.rawValue) handles one concrete piece of coordination.",
                    body: "\(actor.rawValue) says:\n\n“I can look at two possibilities for our next plan and send them tomorrow.”"
                ),
                Scenario(
                    id: "receiver-support-quiet",
                    title: "Stay together quietly",
                    summary: "\(actor.rawValue) offers company without another discussion.",
                    body: "\(actor.rawValue) says:\n\n“We don’t have to work anything out tonight. We can just sit together for a while.”"
                )
            ],
            discussionQuestions: [
                "Would \(receiver.rawValue) choose differently before versus after work?",
                "Which support could \(actor.rawValue) repeat?",
                "What is one smaller version of the preferred option?"
            ],
            suggestedReadings: []
        )
    }

    private func planningOwnershipRound(receiver: Perspective, actor: Perspective) -> ScenarioRound {
        ScenarioRound(
            id: "generated-planning-ownership",
            opening: "It is Thursday evening. No time has been chosen for the weekend.",
            openingQuestion: "\(actor.rawValue) could take on different parts of making the next plan.",
            currentDayIndex: 3,
            targetDayIndex: 5,
            timelineTargetLabel: "",
            focusPerspective: receiver,
            qiyuPrompt: prompt(for: .qiyu, receiver: receiver),
            samarPrompt: prompt(for: .samar, receiver: receiver),
            testedVariableLabel: "Which planning task is shared",
            testVariable: "Choosing the time, choosing the activity, or initiating a planning check-in.",
            potentialVariables: ["Choose time", "Choose activity", "Start check-in"],
            heldConstant: ["Thursday evening", "No existing weekend plan"],
            rationale: "Instead of treating planning as one task, this comparison separates three concrete parts of it.",
            scenarios: [
                Scenario(
                    id: "ownership-time",
                    title: "Offer a time",
                    summary: "\(actor.rawValue) proposes when to meet.",
                    body: "\(actor.rawValue) sends:\n\n“Would Sunday afternoon work for you?”"
                ),
                Scenario(
                    id: "ownership-activity",
                    title: "Offer an activity",
                    summary: "\(actor.rawValue) proposes what to do and leaves the time open.",
                    body: "\(actor.rawValue) sends:\n\n“I’d like to cook together this weekend. Is there a time that could work?”"
                ),
                Scenario(
                    id: "ownership-checkin",
                    title: "Start the check-in",
                    summary: "\(actor.rawValue) begins planning without proposing a solution.",
                    body: "\(actor.rawValue) sends:\n\n“Should we look at the weekend together tonight?”"
                )
            ],
            discussionQuestions: [
                "Which part of planning is most tiring for \(receiver.rawValue)?",
                "Which part feels easiest for \(actor.rawValue) to take on?",
                "Would alternating one task feel more sustainable?"
            ],
            suggestedReadings: []
        )
    }

    private func prompt(for person: Perspective, receiver: Perspective) -> String {
        person == receiver
            ? "Which would feel good for \(person.rawValue) to receive?"
            : "Which could \(person.rawValue) comfortably do?"
    }

    func reorderAfterAnswer(
        _ rounds: [ScenarioRound],
        completedIndex: Int,
        answersMatch: Bool
    ) -> [ScenarioRound] {
        guard !answersMatch,
              rounds.indices.contains(completedIndex),
              completedIndex + 1 < rounds.count
        else { return rounds }

        let bridgeByRound: [String: String] = [
            "advance-notice": "busy-week-boundary",
            "who-asks-first": "advance-notice",
            "busy-week-boundary": "busy-day-update",
            "sharing-small-joy": "support-after-hard-day",
            "busy-day-update": "advance-notice",
            "support-after-hard-day": "conflict-first-step",
            "conflict-first-step": "pause-and-return",
            "pause-and-return": "conflict-first-step",
            "shared-time-rhythm": "advance-notice",
            "generated-coordination-load": "generated-planning-ownership",
            "generated-work-boundary": "generated-support",
            "generated-recognition": "generated-support",
            "generated-support": "generated-coordination-load",
            "generated-planning-ownership": "generated-coordination-load"
        ]

        guard let bridgeID = bridgeByRound[rounds[completedIndex].id],
              let bridgeIndex = rounds[(completedIndex + 1)...].firstIndex(where: { $0.id == bridgeID }),
              bridgeIndex != completedIndex + 1
        else { return rounds }

        var reordered = rounds
        let bridge = reordered.remove(at: bridgeIndex)
        reordered.insert(bridge, at: completedIndex + 1)
        return reordered
    }
}
