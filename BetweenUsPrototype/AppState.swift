import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private static let productionCloudGeneratorURL =
        "https://two-humans-communication-1.onrender.com"

    @Published var stage: AppStage = .qiyuHome
    @Published var reflectionOwner: Perspective = .qiyu
    @Published var entryMode: ReflectionEntryMode = .concreteMoment
    @Published var scenarioSourceMode: ScenarioSourceMode = .adaptive
    @Published var feeling: String = ""
    @Published var isAIEnabled: Bool = UserDefaults.standard.object(
        forKey: "between-us.ai-enabled"
    ) as? Bool ?? true
    @Published var selectedPersonName: String = "Qiyu"
    @Published var selectedSuggestedPrompt: String?
    @Published var savedPersonNames: [String] = ["Qiyu", "Samar"]
    @Published var personPromptHistory: [String: [String]] = [:]
    @Published var sharedExperiment: String = ""
    @Published private(set) var adaptiveRounds: [ScenarioRound] = []
    @Published var isGeneratingScenarios = false
    @Published var isPreparingNextRound = false
    @Published var generationError: String?
    @Published var generationNotice: String?
    @Published var cloudGeneratorURL: String

    @Published var qiyuChoiceID: String?
    @Published var samarPredictionID: String?
    @Published var qiyuLocked = false
    @Published var samarLocked = false
    @Published var currentRoundIndex = 0
    @Published var currentQuestionNumber = 0
    @Published var showDiscussionQuestions = false
    @Published var roundRecords: [RoundAnswerRecord] = []
    @Published var savedSessions: [SavedSession] = []
    @Published var selectedSessionID: UUID?
    @Published var profiles: [PersonProfile] = []

    private let historyKey = "between-us.saved-sessions"
    private let profilesKey = "between-us.person-profiles"
    private let peopleKey = "between-us.saved-people"
    private let personPromptsKey = "between-us.person-prompts"
    private let selectedPersonKey = "between-us.selected-person"
    private let aiEnabledKey = "between-us.ai-enabled"
    private var profileReturnStage: AppStage = .perspective
    private let adaptiveEngine = LocalAdaptiveScenarioEngine()
    private let onDeviceScenarioService = OnDeviceScenarioService()
    private let cloudURLKey = "between-us.cloud-generator-url"
    private var isPrefetchingScenarios = false

    init() {
        let savedCloudURL = UserDefaults.standard.string(
            forKey: "between-us.cloud-generator-url"
        )
        if savedCloudURL == nil || savedCloudURL == "http://127.0.0.1:8787" {
            cloudGeneratorURL = Self.productionCloudGeneratorURL
            UserDefaults.standard.set(
                Self.productionCloudGeneratorURL,
                forKey: "between-us.cloud-generator-url"
            )
        } else {
            cloudGeneratorURL = savedCloudURL!
        }
        loadHistory()
        loadProfiles()
        loadPeople()
    }

    let rounds: [ScenarioRound] = [
        ScenarioRound(
            id: "advance-notice",
            opening: "It is near the end of the workweek. Samar has several tight deadlines and does not yet know when he will finish.",
            openingQuestion: "The weekend is still unclear.",
            currentDayIndex: 4,
            targetDayIndex: 6,
            timelineTargetLabel: "",
            focusPerspective: .samar,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably do on a real week?",
            testedVariableLabel: "How planning begins",
            testVariable: "What initiates Samar’s planning behavior while his availability remains uncertain.",
            potentialVariables: [
                "Early update",
                "Response after a question",
                "Workload",
                "Certainty"
            ],
            heldConstant: [
                "Friday morning",
                "The same unfinished work",
                "Weekend availability is unclear"
            ],
            rationale: "Both options begin with the same uncertainty. What changes is whether Samar defines the next update himself or waits until Qiyu asks.",
            scenarios: [
                Scenario(
                    id: "early-update",
                    title: "Name the next update",
                    summary: "Samar sends an early update and names when he will follow up.",
                    body: "Before his schedule is clear, Samar messages Qiyu:\n\n“I still don’t know what the weekend looks like. I’ll check again later today and update you.”\n\nHe sends the update when he said he would, whether or not his schedule is clear."
                ),
                Scenario(
                    id: "respond-after-ask",
                    title: "Respond after Qiyu asks",
                    summary: "Qiyu’s question prompts Samar to review the work and respond.",
                    body: "Samar waits while he works. When Qiyu asks, “Do you know what your weekend looks like?”, he reviews what remains and replies with what he currently knows."
                )
            ],
            discussionQuestions: [
                "Which part of the other behavior would be difficult for Samar to repeat?",
                "Does Qiyu most need a possible time, or to know when Samar will return with information?",
                "What is the smallest version both people could use during an uncertain week?"
            ],
            suggestedReadings: [
                SuggestedReading(
                    id: "bids-trust",
                    title: "An introduction to emotional bids and trust",
                    source: "The Gottman Institute",
                    takeaway: "Small attempts to create connection can carry meaning beyond the activity itself.",
                    url: "https://www.gottman.com/blog/an-introduction-to-emotional-bids-and-trust/"
                ),
                SuggestedReading(
                    id: "turn-toward",
                    title: "Turn toward instead of away",
                    source: "The Gottman Institute",
                    takeaway: "A practical lens for discussing how each person notices and responds to bids.",
                    url: "https://www.gottman.com/blog/turn-toward-instead-of-away/"
                )
            ]
        ),
        ScenarioRound(
            id: "who-asks-first",
            opening: "It is near the end of the week. Qiyu and Samar last saw each other several days ago. Their most recent messages were about work and dinner.",
            openingQuestion: "The next exchange could happen in either of these ways.",
            currentDayIndex: 3,
            targetDayIndex: 6,
            timelineTargetLabel: "",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably do?",
            testedVariableLabel: "Who asks first",
            testVariable: "Who begins the planning conversation: Qiyu or Samar.",
            potentialVariables: [
                "When the plan is made",
                "Who asks first",
                "Time together",
                "Activity",
                "Workload",
                "The time being proposed"
            ],
            heldConstant: [
                "The same point near the end of the week",
                "Sunday evening",
                "The same proposed time",
                "The same reply"
            ],
            rationale: "The day, activity, and final plan stay the same. Changing only who sends the first message tests whether initiation itself affects the experience.",
            scenarios: [
                Scenario(
                    id: "qiyu-asks",
                    title: "Qiyu asks first",
                    summary: "Qiyu begins the conversation.",
                    body: "Qiyu asks:\n\n“What does your weekend look like?”\n\nSamar checks and replies:\n\n“I can do Sunday evening. Does that work for you?”"
                ),
                Scenario(
                    id: "samar-asks",
                    title: "Samar asks first",
                    summary: "Samar begins the conversation.",
                    body: "Samar checks his weekend and sends:\n\n“I can do Sunday evening. Does that work for you?”"
                )
            ],
            discussionQuestions: [
                "What changes when the same time is offered but Samar sends the first message?",
                "Does Qiyu want Samar to choose the activity, or simply begin the conversation?",
                "How often would Samar starting the plan make a noticeable difference?"
            ],
            suggestedReadings: [
                SuggestedReading(
                    id: "turn-toward",
                    title: "Turn toward instead of away",
                    source: "The Gottman Institute",
                    takeaway: "Explore the difference between making a bid, noticing one, and responding to one.",
                    url: "https://www.gottman.com/blog/turn-toward-instead-of-away/"
                ),
                SuggestedReading(
                    id: "bids-trust",
                    title: "An introduction to emotional bids and trust",
                    source: "The Gottman Institute",
                    takeaway: "Why small moments of reaching out can become evidence of participation in a relationship.",
                    url: "https://www.gottman.com/blog/an-introduction-to-emotional-bids-and-trust/"
                )
            ]
        ),
        ScenarioRound(
            id: "busy-week-boundary",
            opening: "It is the start of the week. Samar has several tight deadlines and does not know how late he will need to work.",
            openingQuestion: "Samar could communicate before or after the times are confirmed.",
            currentDayIndex: 0,
            targetDayIndex: 5,
            timelineTargetLabel: "",
            focusPerspective: .samar,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably repeat during a busy week?",
            testedVariableLabel: "Advance notice or certainty",
            testVariable: "Early but tentative information versus later but confirmed information.",
            potentialVariables: [
                "Tentative or confirmed",
                "When the message is sent",
                "Who asks first",
                "Workload",
                "Follow-up day",
                "Time together"
            ],
            heldConstant: [
                "Unpredictable work hours",
                "The same weekend",
                "One possible meeting time",
                "A later confirmation"
            ],
            rationale: "This comparison was chosen to test the overlap between early communication and an unpredictable work schedule—not how much either person cares.",
            scenarios: [
                Scenario(
                    id: "early-tentative",
                    title: "Earlier and tentative",
                    summary: "A possible time is named near the start of the week.",
                    body: "Near the start of the week, Samar sends:\n\n“Saturday afternoon might work. I’ll know more later in the week and update you then.”\n\nHe follows up when he said he would."
                ),
                Scenario(
                    id: "confirm-thursday",
                    title: "Later and confirmed",
                    summary: "A confirmed time is named later in the week.",
                    body: "Samar waits until the deadlines are under control and he knows when he can finish. Later in the week, he sends without being asked:\n\n“Saturday afternoon is open. Does that work for you?”"
                )
            ],
            discussionQuestions: [
                "Which part of the other option would be difficult for Samar to repeat every week?",
                "Can Samar suggest a possible time before he can confirm it?",
                "What follow-up day would be realistic during a twelve-hour work week?"
            ],
            suggestedReadings: [
                SuggestedReading(
                    id: "bids-trust",
                    title: "An introduction to emotional bids and trust",
                    source: "The Gottman Institute",
                    takeaway: "A bid can communicate interest even when a person cannot immediately provide the requested time.",
                    url: "https://www.gottman.com/blog/an-introduction-to-emotional-bids-and-trust/"
                ),
                SuggestedReading(
                    id: "plan-relationship",
                    title: "How to plan a successful relationship",
                    source: "The Gottman Institute",
                    takeaway: "A broader view of maintaining connection while real life continues around the relationship.",
                    url: "https://www.gottman.com/blog/how-to-plan-a-successful-relationship/"
                )
            ]
        ),
        ScenarioRound(
            id: "sharing-small-joy",
            opening: "Near sunset, Qiyu walks outside and sees an orange sky above the buildings. She sends Samar a photograph with the message, “Look at this.”",
            openingQuestion: "Samar’s attention could go to different parts of the moment.",
            currentDayIndex: 2,
            targetDayIndex: 2,
            timelineTargetLabel: "Sunset",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably send?",
            testedVariableLabel: "Where attention goes",
            testVariable: "Whether Samar attends to the image, Qiyu’s experience, or the act of sharing.",
            potentialVariables: [
                "Reply speed",
                "The image",
                "Qiyu’s experience",
                "The act of sharing",
                "Reply length"
            ],
            heldConstant: [
                "The same sunset photograph",
                "The same sunset photo",
                "A text reply"
            ],
            rationale: "Both replies respond to the same photograph. What changes is whether Samar places his attention on the image itself or on Qiyu’s choice to share it.",
            scenarios: [
                Scenario(
                    id: "sunset-acknowledge",
                    title: "The image",
                    summary: "Samar responds to what is visible in the photograph.",
                    body: "Samar responds:\n\n“The colors are beautiful.”"
                ),
                Scenario(
                    id: "sunset-sharing",
                    title: "The act of sharing",
                    summary: "Samar responds to Qiyu choosing to share the moment.",
                    body: "Samar responds:\n\n“I like that you thought to send this to me.”"
                )
            ],
            discussionQuestions: [
                "What does the second sentence add for Qiyu?",
                "Would the response feel different if it arrived two hours later?",
                "What kind of small moment does Samar naturally want to share?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "busy-day-update",
            opening: "At the start of a workday, Samar sees that his meetings run back-to-back until late. His first meeting is about to begin.",
            openingQuestion: "Samar could communicate before work or reconnect afterward.",
            currentDayIndex: 1,
            targetDayIndex: 1,
            timelineTargetLabel: "Busy day",
            focusPerspective: .samar,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably do?",
            testedVariableLabel: "When the update is sent",
            testVariable: "Whether Samar sends a short update before becoming unavailable or initiates contact after work ends.",
            potentialVariables: [
                "Before or after work",
                "Message length",
                "Work hours",
                "Who initiates",
                "Invitation to continue"
            ],
            heldConstant: [
                "The same Tuesday workload",
                "No daytime conversation",
                "Samar initiates one message",
                "The work schedule is mentioned"
            ],
            rationale: "Both versions contain one message initiated by Samar and no daytime conversation. The comparison changes whether he communicates before becoming unavailable or reconnects after the workday ends.",
            scenarios: [
                Scenario(
                    id: "busy-update-morning",
                    title: "Before work",
                    summary: "The update arrives before the meetings.",
                    body: "Before the meetings begin, Samar sends:\n\n“Meetings all day. I probably won’t reply while I’m working. I’ll text when I’m done.”"
                ),
                Scenario(
                    id: "busy-update-evening",
                    title: "After work",
                    summary: "The update arrives after Qiyu asks.",
                    body: "Samar enters the meetings without sending an update. After the final meeting, he initiates:\n\n“Just finished. Meetings ran all day. How was your day?”"
                )
            ],
            discussionQuestions: [
                "What changes when the same information arrives before the silence?",
                "How early could Samar realistically know enough to send an update?",
                "Which busy days would not allow even the morning message?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "support-after-hard-day",
            opening: "Qiyu meets Samar after work and says, “Today was exhausting.” They have a short time together before she needs to leave.",
            openingQuestion: "The next thirty minutes could look like one of these.",
            currentDayIndex: 2,
            targetDayIndex: 2,
            timelineTargetLabel: "30 minutes",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably offer?",
            testedVariableLabel: "Kind of support",
            testVariable: "Whether the available time is used for listening or practical help.",
            potentialVariables: [
                "Listening",
                "Practical help",
                "Physical closeness",
                "Advice",
                "Time alone"
            ],
            heldConstant: [
                "Wednesday evening",
                "Thirty minutes together",
                "Qiyu is tired",
                "No attempt to solve the work problem"
            ],
            rationale: "The available time and situation stay fixed while the form of support changes. This helps each person name a concrete response instead of choosing an abstract love-language label.",
            scenarios: [
                Scenario(
                    id: "support-listen",
                    title: "Walk and listen",
                    summary: "They walk while Qiyu talks.",
                    body: "Samar says:\n\n“Tell me what happened.”\n\nHe walks with her and listens."
                ),
                Scenario(
                    id: "support-practical",
                    title: "Food and one task",
                    summary: "Samar handles one practical need.",
                    body: "Samar says:\n\n“Let’s get you something to eat before you leave.”"
                )
            ],
            discussionQuestions: [
                "Would Qiyu choose differently if she were upset rather than tired?",
                "Which response feels most natural for Samar to offer?",
                "What question could Samar ask when he does not know which kind of support is wanted?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "conflict-first-step",
            opening: "Qiyu and Samar planned to meet after work. A few hours before the plan, Samar said work had changed and he could not come. Qiyu later told him that finding out so late hurt. The next morning, they have a short time to talk.",
            openingQuestion: "The conversation could begin in either of these ways.",
            currentDayIndex: 5,
            targetDayIndex: 5,
            timelineTargetLabel: "15-minute talk",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which would feel good for Qiyu to hear first?",
            samarPrompt: "Which could Samar comfortably say first?",
            testedVariableLabel: "Impact or context first",
            testVariable: "Whether the conversation begins with Qiyu’s experience or Samar’s work context.",
            potentialVariables: [
                "Acknowledging impact",
                "Explaining intent",
                "Proposing a solution",
                "Apologizing",
                "Conversation length"
            ],
            heldConstant: [
                "The same Friday change",
                "Saturday morning",
                "Fifteen minutes",
                "A future plan is discussed"
            ],
            rationale: "Both conversations include the same amount of time and eventually discuss what to do next. Only the first step changes.",
            scenarios: [
                Scenario(
                    id: "conflict-impact-first",
                    title: "Impact first",
                    summary: "Samar asks about Qiyu’s experience before explaining.",
                    body: "Samar says:\n\n“Can you tell me what it was like to find out so close to our plan?”\n\nHe listens, then explains what changed at work."
                ),
                Scenario(
                    id: "conflict-solution-first",
                    title: "Context first",
                    summary: "Samar explains what changed before asking about Qiyu’s experience.",
                    body: "Samar says:\n\n“My manager added a task that had to be finished that night.”\n\nHe explains, then asks what it was like for Qiyu to find out so close to their plan."
                )
            ],
            discussionQuestions: [
                "Does the order change how easy it is for Qiyu to listen?",
                "Which opening would be easier for Samar to say sincerely?",
                "What would Qiyu want to say first if the roles were reversed?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "pause-and-return",
            opening: "It is late at night. Qiyu and Samar have discussed the same topic for a while, and several points have been repeated. Both need to start work early the next morning.",
            openingQuestion: "The pause could happen in either of these ways.",
            currentDayIndex: 6,
            targetDayIndex: 1,
            timelineTargetLabel: "",
            focusPerspective: .samar,
            qiyuPrompt: "Which would feel good for Qiyu to hear?",
            samarPrompt: "Which could Samar comfortably say and follow through on?",
            testedVariableLabel: "How the pause is communicated",
            testVariable: "Whether the pause includes a specific return time and a statement of continued care.",
            potentialVariables: [
                "Pause length",
                "Return time",
                "Reassurance",
                "Who restarts",
                "Contact the next day"
            ],
            heldConstant: [
                "The same late-night conversation",
                "Early work the next morning",
                "No resolution that night",
                "The conversation resumes Tuesday"
            ],
            rationale: "Both options stop the late-night conversation and return on Tuesday. The comparison changes whether the return is explicitly named before the pause.",
            scenarios: [
                Scenario(
                    id: "pause-with-return",
                    title: "Pause with a return time",
                    summary: "Tuesday is named before they stop.",
                    body: "Samar says:\n\n“We’re repeating ourselves, and we both need sleep. Can we continue tomorrow evening?”"
                ),
                Scenario(
                    id: "pause-without-return",
                    title: "Pause without a return time",
                    summary: "The conversation stops until Tuesday.",
                    body: "Samar says:\n\n“We’re repeating ourselves, and we both need sleep. I need to check tomorrow’s schedule. I’ll message you in the morning with a time to continue.”"
                )
            ],
            discussionQuestions: [
                "Which sentence makes the pause feel different?",
                "How specific does the return time need to be?",
                "What should happen if Tuesday at 7 becomes unavailable?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "shared-time-rhythm",
            opening: "Near the end of the week, Samar checks Saturday and sees that most of the day is open.",
            openingQuestion: "Samar could send either of these invitations.",
            currentDayIndex: 3,
            targetDayIndex: 5,
            timelineTargetLabel: "",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which invitation would feel good for Qiyu to receive?",
            samarPrompt: "Which invitation could Samar comfortably make?",
            testedVariableLabel: "Amount of shared time",
            testVariable: "Whether they spend all eight available hours together or keep four hours for separate time.",
            potentialVariables: [
                "Hours together",
                "Activity",
                "Location",
                "Separate time",
                "Who plans"
            ],
            heldConstant: [
                "The same Saturday",
                "The same available window",
                "Lunch and a hike",
                "The invitation is sent near the end of the week"
            ],
            rationale: "The day, activities, and planning time stay the same. Only the amount of shared versus separate time changes.",
            scenarios: [
                Scenario(
                    id: "shared-eight-hours",
                    title: "Most of the day",
                    summary: "They use the full available window together.",
                    body: "Samar sends:\n\n“I have most of Saturday open. Want to get coffee, have lunch, go for a walk, and spend the day together?”"
                ),
                Scenario(
                    id: "shared-four-hours",
                    title: "The afternoon",
                    summary: "They keep the morning separate.",
                    body: "Samar sends:\n\n“I’m free Saturday afternoon. Want to go for a walk and get an early dinner?”"
                )
            ],
            discussionQuestions: [
                "Would the answer change after a week with more time together?",
                "How much unplanned time together feels enjoyable rather than obligatory?",
                "What amount of separate time helps each person arrive more present?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "plan-changes",
            opening: "Qiyu and Samar planned to meet after work. A few hours before the plan, Samar’s manager adds an urgent task that will take the rest of the workday.",
            openingQuestion: "Samar could respond in either of these ways.",
            currentDayIndex: 4,
            targetDayIndex: 6,
            timelineTargetLabel: "",
            focusPerspective: .samar,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably do?",
            testedVariableLabel: "Alternative or follow-up",
            testVariable: "An immediate alternative versus a clearly owned follow-up.",
            potentialVariables: ["Immediate alternative", "Defined follow-up", "Certainty", "Timing"],
            heldConstant: ["The same urgent work task", "The existing plan cannot happen", "Samar communicates as soon as he knows"],
            rationale: "Both behaviors communicate the change immediately. One offers another time; the other defines when Samar will return with one.",
            scenarios: [
                Scenario(
                    id: "change-immediate-alternative",
                    title: "Offer another time",
                    summary: "Samar checks and includes another time immediately.",
                    body: "Samar checks the next few days and sends:\n\n“I can’t make it tonight. Could we do Sunday afternoon instead?”"
                ),
                Scenario(
                    id: "change-defined-followup",
                    title: "Own the follow-up",
                    summary: "Samar names when he will return with another time.",
                    body: "Samar has not checked the rest of the weekend. He sends:\n\n“I can’t make it tonight. I need to check the weekend. I’ll send you another time tomorrow.”"
                )
            ],
            discussionQuestions: [
                "Which part matters more: receiving another time now or knowing when one will come?",
                "What makes offering an immediate alternative difficult?",
                "What follow-up deadline could Samar reliably keep?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "response-timing",
            opening: "One of Samar’s meetings ends a little early. Several work messages are waiting. He sees a photograph Qiyu sent earlier, and his next meeting begins soon.",
            openingQuestion: "Both versions use exactly the same response.",
            currentDayIndex: 2,
            targetDayIndex: 2,
            timelineTargetLabel: "Reply",
            focusPerspective: .samar,
            qiyuPrompt: "Which timing would feel good for Qiyu?",
            samarPrompt: "Which timing could Samar comfortably repeat?",
            testedVariableLabel: "Response timing",
            testVariable: "The timing of the same response: during a short work break or after the workday.",
            potentialVariables: ["Response timing", "Message content", "Work interruption", "Reply expectation"],
            heldConstant: ["The same photograph", "The same reply", "The same workday"],
            rationale: "The words stay identical. Only the moment Samar sends them changes.",
            scenarios: [
                Scenario(
                    id: "reply-between-meetings",
                    title: "During the break",
                    summary: "The response arrives before the next meeting.",
                    body: "During the short break before his next meeting, Samar sends:\n\n“The colors are beautiful. Where did you take it?”"
                ),
                Scenario(
                    id: "reply-after-work",
                    title: "After work",
                    summary: "The response arrives after Samar’s meetings.",
                    body: "After his meetings end for the day, Samar sends:\n\n“The colors are beautiful. Where did you take it?”"
                )
            ],
            discussionQuestions: [
                "Does Qiyu need a full response during work, or only a sign that the message was seen?",
                "What makes responding during a short break uncomfortable for Samar?",
                "Would a reaction now and a question later feel different?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "good-news",
            opening: "Qiyu receives an email saying her proposal was approved. She sends Samar, “It got approved!” Samar opens the message shortly before his next meeting.",
            openingQuestion: "Samar could join the moment in either of these ways.",
            currentDayIndex: 2,
            targetDayIndex: 2,
            timelineTargetLabel: "Good news",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably send?",
            testedVariableLabel: "How joy is joined",
            testVariable: "Recognizing Qiyu’s effort versus creating a shared celebration.",
            potentialVariables: ["Recognition", "Celebration", "Response length", "Future plan"],
            heldConstant: ["The same approval message", "Shortly before a meeting"],
            rationale: "This preference-discovery question compares recognizing the work behind good news with creating a shared celebration. Neither represents a higher level of care.",
            scenarios: [
                Scenario(
                    id: "news-recognition",
                    title: "Recognize the work",
                    summary: "Samar names the effort behind the result.",
                    body: "Before his next meeting, Samar sends:\n\n“You put so much work into that proposal. I’m really happy it was recognized.”"
                ),
                Scenario(
                    id: "news-celebrate",
                    title: "Celebrate together",
                    summary: "Samar suggests a shared celebration.",
                    body: "Before his next meeting, Samar sends:\n\n“That’s exciting. Want to celebrate together this weekend?”"
                )
            ],
            discussionQuestions: [
                "What does Qiyu want Samar to notice first in a positive moment?",
                "Which response feels most natural for Samar?",
                "Would the answer change for smaller good news?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "physical-reconnection",
            opening: "Qiyu arrives outside a restaurant. Samar is waiting near the entrance. They last saw each other about a week ago, and their table will be ready soon. Hugging has been comfortable for them before.",
            openingQuestion: "Their first few minutes could begin in different ways.",
            currentDayIndex: 5,
            targetDayIndex: 5,
            timelineTargetLabel: "Reconnecting",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which would feel good for Qiyu?",
            samarPrompt: "Which could Samar comfortably initiate?",
            testedVariableLabel: "Physical reconnection",
            testVariable: "How physical closeness begins after time apart.",
            potentialVariables: ["Hug", "Conversation first", "Walking together", "Touch timing"],
            heldConstant: ["The same restaurant", "One week apart", "Five minutes before the table is ready"],
            rationale: "The comparison explores comfortable forms of reconnection. It does not treat more immediate touch as more affection.",
            scenarios: [
                Scenario(
                    id: "reconnect-hug",
                    title: "Begin with a hug",
                    summary: "Samar offers a hug before they begin talking.",
                    body: "Samar walks toward Qiyu and opens his arms for a hug before they begin talking."
                ),
                Scenario(
                    id: "reconnect-walk",
                    title: "Walk first",
                    summary: "They begin by walking; physical touch happens later.",
                    body: "Samar greets Qiyu and suggests walking around the block while they wait. Physical touch happens later."
                )
            ],
            discussionQuestions: [
                "What makes a greeting feel warm without feeling scripted?",
                "Which form of reconnection is easiest for Samar to initiate?",
                "How could either person check what feels welcome in the moment?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "repair-next-step",
            opening: "Samar has explained why a recent plan changed. Qiyu has explained that finding out shortly beforehand made her feel unprepared and uncertain about when they would meet again. They have a little time left to talk.",
            openingQuestion: "The conversation could stay with understanding or move toward a future behavior.",
            currentDayIndex: 5,
            targetDayIndex: 5,
            timelineTargetLabel: "Next step",
            focusPerspective: .qiyu,
            qiyuPrompt: "Which would feel good for Qiyu next?",
            samarPrompt: "Which could Samar comfortably do next?",
            testedVariableLabel: "Understanding or action",
            testVariable: "Continuing emotional understanding versus moving into practical repair.",
            potentialVariables: ["More understanding", "Future behavior", "Remaining time", "Specificity"],
            heldConstant: ["The context is understood", "Qiyu’s impact is known", "Five minutes remain"],
            rationale: "Both people have already shared their perspectives. This question tests which next step each person prefers and can sustain.",
            scenarios: [
                Scenario(
                    id: "repair-understand-more",
                    title: "Understand more",
                    summary: "Samar asks which part of the experience was hardest.",
                    body: "Samar asks:\n\n“Which part was hardest—the plan changing, finding out late, or not knowing when we would meet again?”"
                ),
                Scenario(
                    id: "repair-future-action",
                    title: "Define a future behavior",
                    summary: "Samar proposes a repeatable action for the next change.",
                    body: "Samar says:\n\n“Next time a plan changes, I’ll tell you as soon as I know and include when I can give you another time.”"
                )
            ],
            discussionQuestions: [
                "Does Qiyu feel understood enough to discuss a solution?",
                "Would Samar need the future behavior to be smaller or more flexible?",
                "What would signal that it is time to move from understanding to action?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "weekend-social-allocation",
            opening: "Samar has said work is busy. He has a birthday party Friday night and another birthday party Saturday night. He offers Qiyu Sunday dinner. Qiyu does not know exactly how the remaining daytime hours are being used.",
            openingQuestion: "Samar could keep or rearrange the existing social plans.",
            currentDayIndex: 4,
            targetDayIndex: 6,
            timelineTargetLabel: "Weekend",
            focusPerspective: .samar,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably do?",
            testedVariableLabel: "Rearranging social time",
            testVariable: "Whether Samar keeps both birthday commitments as planned or shortens one to create a larger shared block.",
            potentialVariables: [
                "Amount of shared time",
                "Keeping prior commitments",
                "Rearranging social time",
                "Workload"
            ],
            heldConstant: [
                "The same demanding workweek",
                "A birthday party Friday night",
                "A birthday party Saturday night",
                "Samar initiates the plan"
            ],
            rationale: "The opening separates confirmed information from Qiyu’s assumption about the rest of the weekend. Both options include Samar initiating time with Qiyu. What changes is whether he keeps both birthday nights as planned or rearranges one to create more shared time.",
            scenarios: [
                Scenario(
                    id: "keep-social-plans",
                    title: "Keep the existing plans",
                    summary: "Samar keeps both birthday commitments and offers the open dinner.",
                    body: "Samar keeps both birthday nights as arranged and sends Qiyu:\n\n“I have the birthday parties Friday and Saturday night, but Sunday dinner is open. Does that work for you?”"
                ),
                Scenario(
                    id: "rearrange-social-plan",
                    title: "Create a larger block",
                    summary: "Samar shortens one birthday visit and offers one of those evenings as shared time.",
                    body: "Samar decides to shorten one birthday visit and sends Qiyu:\n\n“I’m going to stop by the birthday briefly, but I can keep the rest of that evening open for us. Does that work?”"
                )
            ],
            discussionQuestions: [
                "Is the meaningful difference the number of hours or Samar’s willingness to rearrange something?",
                "What makes changing an existing social commitment comfortable or uncomfortable for Samar?",
                "Would planning a longer time the following week meet the same need for Qiyu?"
            ],
            suggestedReadings: []
        ),
        ScenarioRound(
            id: "weekend-protected-time",
            opening: "At the start of the week, Samar says work will be busy. He has a birthday party Friday night and another birthday party Saturday night. How he will use the remaining daytime has not been decided in this scenario.",
            openingQuestion: "Keeping both birthday nights, the remaining time could be arranged using either of these rules.",
            currentDayIndex: 0,
            targetDayIndex: 6,
            timelineTargetLabel: "Weekend",
            focusPerspective: .samar,
            qiyuPrompt: "Which would feel good for Qiyu to receive?",
            samarPrompt: "Which could Samar comfortably do?",
            testedVariableLabel: "How time is protected",
            testVariable: "Whether the remaining daytime is left for work and recovery or one relationship block is protected before the work is arranged.",
            potentialVariables: [
                "Protected relationship time",
                "Fixed-date social events",
                "Work and recovery time",
                "Order of scheduling",
                "Amount of shared time"
            ],
            heldConstant: [
                "The same stated work pressure",
                "The same Friday and Saturday birthday parties",
                "Sunday dinner remains available"
            ],
            rationale: "This comparison keeps both birthday nights unchanged. It tests how the still-unplanned daytime is allocated between work, recovery, and relationship time. Neither option assumes how Samar actually used those hours this weekend.",
            scenarios: [
                Scenario(
                    id: "fixed-events-first",
                    title: "Keep the daytime flexible",
                    summary: "Samar leaves the daytime available for work or recovery and offers Sunday dinner.",
                    body: "Samar keeps both birthday nights and leaves the remaining daytime available for work or recovery. He sends Qiyu:\n\n“I need the daytime for work and to reset, but Sunday dinner is open. Does that work for you?”"
                ),
                Scenario(
                    id: "protect-relationship-block",
                    title: "Protect a daytime block",
                    summary: "Samar reserves one daytime relationship block before arranging the work.",
                    body: "Samar keeps both birthday nights. Before arranging the remaining work, he reserves one daytime block for Qiyu and sends:\n\n“I want to keep part of the weekend for us. Would Sunday afternoon and dinner work?”"
                )
            ],
            discussionQuestions: [
                "Is the difficult part the birthday plans, or not knowing how the other hours were allocated?",
                "How much daytime does Samar realistically need for work or recovery on this kind of weekend?",
                "Could a relationship block be protected without changing either birthday plan?"
            ],
            suggestedReadings: []
        )
    ]

    var currentRound: ScenarioRound {
        let availableRounds = activeRounds
        return availableRounds[currentRoundIndex % availableRounds.count]
    }

    var activeRounds: [ScenarioRound] {
        if !adaptiveRounds.isEmpty {
            return adaptiveRounds
        }
        return curatedRoundsInFlowOrder
    }

    private var curatedRoundsInFlowOrder: [ScenarioRound] {
        let ids = [
            "advance-notice",
            "busy-week-boundary",
            "who-asks-first",
            "shared-time-rhythm",
            "weekend-social-allocation",
            "weekend-protected-time",
            "plan-changes",
            "busy-day-update",
            "response-timing",
            "sharing-small-joy",
            "good-news",
            "support-after-hard-day",
            "physical-reconnection",
            "conflict-first-step",
            "repair-next-step",
            "pause-and-return"
        ]

        return ids.compactMap { id in
            rounds.first(where: { $0.id == id })
        }
    }

    var canReveal: Bool { qiyuLocked && samarLocked }

    var answersMatch: Bool {
        guard let qiyuChoiceID, let samarPredictionID else { return false }
        return qiyuChoiceID == samarPredictionID
    }

    func startQiyuFlow() {
        selectPerson(named: "Qiyu")
        stage = .qiyuHome
    }
    func startSamarFlow() {
        selectPerson(named: "Samar")
        stage = .qiyuHome
    }

    func selectPerson(named name: String) {
        guard savedPersonNames.contains(name) else { return }
        if selectedPersonName != name {
            feeling = ""
            selectedSuggestedPrompt = nil
        }
        selectedPersonName = name
        reflectionOwner = name.caseInsensitiveCompare("Samar") == .orderedSame ? .samar : .qiyu
        UserDefaults.standard.set(name, forKey: selectedPersonKey)
    }

    func addPerson(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if !savedPersonNames.contains(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) {
            savedPersonNames.append(name)
            persistPeople()
        }
        selectPerson(named: savedPersonNames.first(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) ?? name)
    }

    var selectedPersonSuggestions: [(label: String, question: String)] {
        if selectedPersonName == "Qiyu" || selectedPersonName == "Samar",
           let profile = profiles.first(where: { $0.id == reflectionOwner }) {
            var seenLabels = Set<String>()
            let profileSuggestions = profile.insights.compactMap { insight
                -> (label: String, question: String)? in
                let label = profileChipLabel(for: insight)
                guard seenLabels.insert(label).inserted else { return nil }
                return (label, profileQuestion(for: insight))
            }
            if !profileSuggestions.isEmpty {
                return Array(profileSuggestions.prefix(4))
            }
        }

        let previous = personPromptHistory[selectedPersonName, default: []]
        if !previous.isEmpty {
            return previous.prefix(5).enumerated().map { index, prompt in
                ("Earlier \(index + 1)", prompt)
            }
        }

        return [
            ("Feeling close", "Which moments make me feel close to someone?"),
            ("Making plans", "What kind of planning feels comfortable to me?"),
            ("Feeling cared for", "Which specific actions make me feel cared for?")
        ]
    }

    var sessionsForSelectedPerson: [SavedSession] {
        savedSessions.filter {
            ($0.ownerName ?? "Qiyu") == selectedPersonName
        }
    }

    var otherParticipantName: String {
        if selectedPersonName.caseInsensitiveCompare("Qiyu") == .orderedSame {
            return "Samar"
        }
        if selectedPersonName.caseInsensitiveCompare("Samar") == .orderedSame {
            return "Qiyu"
        }
        return "The other person"
    }

    func openProfiles(returningTo stage: AppStage) {
        profileReturnStage = stage
        self.stage = .profiles
    }

    func closeProfiles() {
        stage = profileReturnStage
    }

    func updateProfile(_ profile: PersonProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persistProfiles()
    }

    func saveSuggestedInsights(_ suggestions: [ProfileInsightSuggestion]) {
        for suggestion in suggestions {
            guard let profileIndex = profiles.firstIndex(where: { $0.id == suggestion.person }) else {
                continue
            }

            let alreadySaved = profiles[profileIndex].insights.contains {
                $0.kind == suggestion.kind &&
                $0.statement == suggestion.statement &&
                $0.evidence == suggestion.evidence
            }

            guard !alreadySaved else { continue }

            profiles[profileIndex].insights.append(
                ProfileInsight(
                    id: UUID(),
                    kind: suggestion.kind,
                    statement: suggestion.statement,
                    evidence: suggestion.evidence,
                    source: .aiHypothesis
                )
            )
        }
        persistProfiles()
    }

    var personalizationContext: PersonalizationContext {
        PersonalizationContext(
            people: profiles,
            rules: [
                "Use only observable actions, messages, timing, plans, and constraints.",
                "Never claim that either person wants to meet, has the relationship in mind, feels a certain way, or intends an outcome unless the user explicitly provided that fact.",
                "Keep the opening free of inferred mutual interest, assumed availability, and implied plans. Let the scenario options show what each person actually does.",
                "Treat partner observations and AI hypotheses as unconfirmed.",
                "Do not convert a preference into a personality label.",
                "Create two plausible scenarios that change one variable at a time.",
                "Give every question exactly two options.",
                "Write every option as a short, natural scene: establish the moment and show exactly what the person says or does.",
                "Avoid arbitrary clock times and overly precise calendar details. Prefer natural cues such as the start of the week, before work, during a short break, or after work unless exact timing is essential to the user’s example.",
                "Focus the option on a repeatable behavior. Do not add a happy ending or downstream outcome to make the behavior look successful.",
                "Phrase the behavior so it can generalize to similar moments, while keeping one concrete example of what the person might say or do.",
                "Do not use trait labels, experimental-condition headings, or wording that signals which option is more caring or correct.",
                "Ask the receiver what would feel good to receive and the actor what they could comfortably repeat.",
                "Treat a matching choice as overlap, not correctness, and a different choice as a gap to discuss."
            ]
        )
    }

    var suggestedQuestions: [(label: String, question: String)] {
        if reflectionOwner == .samar {
            return [
                ("Work and closeness", "How can I stay close when work is taking most of my energy?"),
                ("An unclear schedule", "What would help both of us when I do not know my schedule yet?"),
                ("Sharing the planning", "Which parts of making plans could Qiyu and I each take on?"),
                ("Asking for space", "How can I ask for focused work time without creating more confusion between us?"),
                ("What support helps me", "What kind of response from Qiyu would actually help when I feel tired or overwhelmed?")
            ]
        }

        return [
            ("Planning when busy", "How should we make plans when one person’s work schedule is unpredictable?"),
            ("Feeling cared for", "Which specific actions make each of us feel cared for?"),
            ("Time together", "How much shared time and separate time feels good to each of us?"),
            ("After conflict", "What should happen first after one of us feels hurt during a conflict?"),
            ("Sharing daily life", "What kind of daily sharing helps each of us feel involved in the other person’s life?")
        ]
    }

    var scenarioGenerationRequest: ScenarioGenerationRequest {
        makeScenarioGenerationRequest(roundCount: 2)
    }

    private func makeScenarioGenerationRequest(roundCount: Int) -> ScenarioGenerationRequest {
        ScenarioGenerationRequest(
            entryMode: entryMode.rawValue,
            userText: feeling,
            personName: selectedPersonName,
            profile: personalizationContext,
            requestedRoundCount: roundCount,
            previousRounds: adaptiveRounds.map {
                GeneratedRoundReference(
                    opening: $0.opening,
                    testedVariableLabel: $0.testedVariableLabel,
                    testVariable: $0.testVariable
                )
            }
        )
    }

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

    func beginScenarioFlowFromHome() {
        entryMode = .concreteMoment
        let usesAuthoredShortcut = selectedSuggestedPrompt == feeling
        scenarioSourceMode = usesAuthoredShortcut
            ? .curated
            : (isAIEnabled ? .adaptive : .curated)
        saveCurrentPromptForSelectedPerson()
        stage = .perspective
    }

    func selectSuggestedQuestion(_ question: String) {
        feeling = question
        selectedSuggestedPrompt = question
    }

    func notePromptWasEdited() {
        guard selectedSuggestedPrompt != feeling else { return }
        selectedSuggestedPrompt = nil
    }

    func setAIEnabled(_ isEnabled: Bool) {
        isAIEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: aiEnabledKey)
    }

    func prepareScenarioFlow(advanceWhenReady: Bool = true) async {
        currentRoundIndex = 0
        currentQuestionNumber = 0
        roundRecords = []
        clearRoundAnswers()
        generationError = nil
        generationNotice = nil

        if scenarioSourceMode == .adaptive {
            isGeneratingScenarios = true
            defer { isGeneratingScenarios = false }

            if onDeviceScenarioService.isAvailable {
                do {
                    adaptiveRounds = try await onDeviceScenarioService.generate(
                        request: scenarioGenerationRequest,
                        receiver: reflectionOwner
                    )
                    generationNotice = "Generated privately by the on-device model."
                } catch {
                    generationError = error.localizedDescription
                    return
                }
            } else {
                let cloudProvider = CloudScenarioService(endpoint: cloudGeneratorURL)
                guard cloudProvider.isAvailable else {
                    generationError = ScenarioGenerationError.cloudNotConfigured.localizedDescription
                    return
                }

                do {
                    adaptiveRounds = try await cloudProvider.generate(
                        request: scenarioGenerationRequest,
                        receiver: reflectionOwner
                    )
                    generationNotice = "Generated by the cloud model because the on-device model is unavailable here."
                    scheduleScenarioPrefetchIfNeeded()
                } catch {
                    generationError = error.localizedDescription
                    return
                }
            }
        } else {
            adaptiveRounds = adaptiveEngine.generate(
                from: rounds,
                userText: feeling,
                profile: personalizationContext,
                receiver: reflectionOwner
            )
        }
        if advanceWhenReady {
            stage = .conversationGuide
        }
    }

    func startHardcodedQuestion(_ question: String) {
        scenarioSourceMode = .curated
        entryMode = .connectionQuestion
        feeling = question
        currentRoundIndex = 0
        currentQuestionNumber = 0
        roundRecords = []
        clearRoundAnswers()
        adaptiveRounds = adaptiveEngine.generate(
            from: rounds,
            userText: question,
            profile: personalizationContext,
            receiver: reflectionOwner
        )
        stage = .conversationGuide
    }

    var isOnDeviceAIAvailable: Bool { onDeviceScenarioService.isAvailable }
    var onDeviceAIStatus: String { onDeviceScenarioService.availabilityDescription }
    var isCloudAIConfigured: Bool {
        CloudScenarioService(endpoint: cloudGeneratorURL).isAvailable
    }

    func saveCloudGeneratorURL(_ value: String) {
        cloudGeneratorURL = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cloudGeneratorURL, forKey: cloudURLKey)
    }

    func startNextRound() async {
        recordCurrentRoundIfNeeded()

        if scenarioSourceMode == .adaptive,
           currentRoundIndex + 1 >= adaptiveRounds.count {
            isPreparingNextRound = true
            defer { isPreparingNextRound = false }
            await waitForPrefetchToFinish()
            if currentRoundIndex + 1 >= adaptiveRounds.count {
                await fetchMoreAdaptiveRounds()
            }
            guard currentRoundIndex + 1 < adaptiveRounds.count else {
                generationError = generationError
                    ?? "The next question could not be prepared. Please try again."
                return
            }
        } else if !adaptiveRounds.isEmpty,
                  scenarioSourceMode != .adaptive {
            adaptiveRounds = adaptiveEngine.reorderAfterAnswer(
                adaptiveRounds,
                completedIndex: currentRoundIndex,
                answersMatch: answersMatch
            )
        }

        currentRoundIndex = scenarioSourceMode == .adaptive
            ? currentRoundIndex + 1
            : (currentRoundIndex + 1) % activeRounds.count
        currentQuestionNumber += 1
        clearRoundAnswers()
        stage = .roundIntro
        scheduleScenarioPrefetchIfNeeded()
    }

    private func scheduleScenarioPrefetchIfNeeded() {
        guard scenarioSourceMode == .adaptive,
              !onDeviceScenarioService.isAvailable,
              adaptiveRounds.count - currentRoundIndex <= 2,
              !isPrefetchingScenarios
        else { return }

        Task { await fetchMoreAdaptiveRounds() }
    }

    private func fetchMoreAdaptiveRounds() async {
        guard scenarioSourceMode == .adaptive,
              !onDeviceScenarioService.isAvailable,
              !isPrefetchingScenarios
        else { return }

        isPrefetchingScenarios = true
        defer { isPrefetchingScenarios = false }

        do {
            let newRounds = try await CloudScenarioService(
                endpoint: cloudGeneratorURL
            ).generate(
                request: makeScenarioGenerationRequest(roundCount: 2),
                receiver: reflectionOwner
            )
            let existingIDs = Set(adaptiveRounds.map(\.id))
            adaptiveRounds.append(
                contentsOf: newRounds.filter { !existingIDs.contains($0.id) }
            )
        } catch {
            generationNotice = "More questions will be prepared when you continue."
        }
    }

    private func waitForPrefetchToFinish() async {
        var checksRemaining = 300
        while isPrefetchingScenarios && checksRemaining > 0 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            checksRemaining -= 1
        }
    }

    func clearCurrentAnswersAndReturnToIntro() {
        clearRoundAnswers()
        stage = .roundIntro
    }

    func resetSession() {
        stage = .qiyuHome
        feeling = ""
        sharedExperiment = ""
        currentRoundIndex = 0
        currentQuestionNumber = 0
        roundRecords = []
        adaptiveRounds = []
        clearRoundAnswers()
    }

    func startNewReflection(mode: ScenarioSourceMode? = nil) {
        if let mode {
            scenarioSourceMode = mode
        }
        feeling = ""
        sharedExperiment = ""
        currentRoundIndex = 0
        currentQuestionNumber = 0
        roundRecords = []
        adaptiveRounds = []
        clearRoundAnswers()
        stage = .qiyuHome
    }

    private func profileChipLabel(for insight: ProfileInsight) -> String {
        let statement = insight.statement.lowercased()

        if statement.contains("next shared plan") || statement.contains("tentative plan") {
            return "Having the next plan"
        }
        if statement.contains("shared experiences") || statement.contains("look forward") {
            return "Things to look forward to"
        }
        if statement.contains("text") || statement.contains("short text") {
            return "Sharing by text"
        }
        if statement.contains("starting the planning") {
            return "Who starts the plan"
        }
        if statement.contains("12 hours") || statement.contains("workday") {
            return "When work runs late"
        }
        if statement.contains("listening carefully") {
            return "Talking through hard things"
        }

        switch insight.kind {
        case .connection: return "A moment together"
        case .constraint: return "A real constraint"
        case .communication: return "How the message arrives"
        case .sustainableAction: return "A repeatable action"
        }
    }

    private func profileQuestion(for insight: ProfileInsight) -> String {
        switch insight.kind {
        case .connection:
            return "Which everyday moments help me feel connected, and what changes between them?"
        case .constraint:
            return "When \(insight.statement.lowercased()), which responses could still work for both people?"
        case .communication:
            return "What could sharing look like when \(insight.statement.lowercased())?"
        case .sustainableAction:
            return "Which small actions related to this feel repeatable: \(insight.statement)"
        }
    }

    func recordCurrentRoundIfNeeded() {
        guard let qiyuChoiceID,
              let samarPredictionID,
              let qiyuChoice = currentRound.scenarios.first(where: { $0.id == qiyuChoiceID }),
              let samarPrediction = currentRound.scenarios.first(where: { $0.id == samarPredictionID })
        else { return }

        let record = RoundAnswerRecord(
            id: "\(currentQuestionNumber)-\(currentRound.id)",
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
            stage = .qiyuHome
            return
        }

        let session = SavedSession(
            id: UUID(),
            createdAt: Date(),
            feeling: feeling,
            answers: roundRecords,
            experiment: sharedExperiment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : sharedExperiment,
            ownerName: selectedPersonName,
            receiver: reflectionOwner
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

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
    }

    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let savedProfiles = try? JSONDecoder().decode([PersonProfile].self, from: data) {
            profiles = savedProfiles
        } else {
            profiles = Self.defaultProfiles
            persistProfiles()
        }
    }

    private func saveCurrentPromptForSelectedPerson() {
        let prompt = feeling.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        var prompts = personPromptHistory[selectedPersonName, default: []]
        prompts.removeAll { $0.caseInsensitiveCompare(prompt) == .orderedSame }
        prompts.insert(prompt, at: 0)
        personPromptHistory[selectedPersonName] = Array(prompts.prefix(12))
        persistPeople()
    }

    private func persistPeople() {
        UserDefaults.standard.set(savedPersonNames, forKey: peopleKey)
        UserDefaults.standard.set(selectedPersonName, forKey: selectedPersonKey)
        if let data = try? JSONEncoder().encode(personPromptHistory) {
            UserDefaults.standard.set(data, forKey: personPromptsKey)
        }
    }

    private func loadPeople() {
        if let names = UserDefaults.standard.stringArray(forKey: peopleKey),
           !names.isEmpty {
            savedPersonNames = names
        }

        if let data = UserDefaults.standard.data(forKey: personPromptsKey),
           let prompts = try? JSONDecoder().decode([String: [String]].self, from: data) {
            personPromptHistory = prompts
        }

        let savedSelection = UserDefaults.standard.string(forKey: selectedPersonKey) ?? "Qiyu"
        if savedPersonNames.contains(savedSelection) {
            selectPerson(named: savedSelection)
        } else {
            selectPerson(named: "Qiyu")
        }
    }

    private func clearRoundAnswers() {
        qiyuChoiceID = nil
        samarPredictionID = nil
        qiyuLocked = false
        samarLocked = false
        showDiscussionQuestions = false
    }

    private static let defaultProfiles: [PersonProfile] = [
        PersonProfile(
            id: .qiyu,
            name: "Qiyu",
            insights: [
                ProfileInsight(
                    id: UUID(),
                    kind: .connection,
                    statement: "Knowing the next shared plan in advance can make a busy week feel different, even when the plan is not happening today.",
                    evidence: "When offered “go today” versus “plan Tuesday now,” Qiyu said planning Tuesday would already make her feel much better.",
                    source: .selfConfirmed
                ),
                ProfileInsight(
                    id: UUID(),
                    kind: .connection,
                    statement: "Shared experiences and something to look forward to matter more than frequent short messages by themselves.",
                    evidence: "Qiyu repeatedly chose a future shared plan or reserved afternoon over daily messages without a shared plan.",
                    source: .selfConfirmed
                ),
                ProfileInsight(
                    id: UUID(),
                    kind: .communication,
                    statement: "Text can support connection, but feels forced when it becomes the only place where the relationship is happening.",
                    evidence: "Text sharing felt natural earlier when dates and shared experiences were also happening.",
                    source: .selfConfirmed
                ),
                ProfileInsight(
                    id: UUID(),
                    kind: .sustainableAction,
                    statement: "A partner starting the planning conversation is meaningfully different from agreeing after Qiyu asks.",
                    evidence: "The same Saturday afternoon felt different depending on who sent the first message.",
                    source: .selfConfirmed
                )
            ]
        ),
        PersonProfile(
            id: .samar,
            name: "Samar",
            insights: [
                ProfileInsight(
                    id: UUID(),
                    kind: .constraint,
                    statement: "Work can take about 12 hours a day, and the end of a workday may be difficult to predict.",
                    evidence: "This has repeatedly shaped when Samar can confirm a plan.",
                    source: .partnerObserved
                ),
                ProfileInsight(
                    id: UUID(),
                    kind: .communication,
                    statement: "During busy periods, Samar often uses short text updates and responds when a specific question is asked.",
                    evidence: "Examples include brief check-ins, photos or videos, and suggesting a time after Qiyu asks about availability.",
                    source: .partnerObserved
                ),
                ProfileInsight(
                    id: UUID(),
                    kind: .sustainableAction,
                    statement: "A tentative plan with a later confirmation may be easier to repeat than committing before the work schedule is known.",
                    evidence: "This is a hypothesis for Samar to confirm, change, or remove.",
                    source: .aiHypothesis
                ),
                ProfileInsight(
                    id: UUID(),
                    kind: .connection,
                    statement: "Listening carefully and calmly during a difficult conversation may be one way Samar participates in the relationship.",
                    evidence: "Qiyu has observed that Samar listens, stays calm, and tries requested changes.",
                    source: .partnerObserved
                )
            ]
        )
    ]
}

protocol DiscussionQuestionProviding {
    func questions(for round: ScenarioRound, selectedScenarioID: String?) -> [String]
}

struct LocalDiscussionQuestionProvider: DiscussionQuestionProviding {
    func questions(for round: ScenarioRound, selectedScenarioID: String?) -> [String] {
        round.discussionQuestions
    }
}
