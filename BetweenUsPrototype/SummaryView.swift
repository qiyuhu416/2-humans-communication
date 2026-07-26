import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var appState: AppState
    let session: SavedSession?
    @State private var expandedAnswer: String?
    @State private var showingAISummary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button {
                        appState.stage = .qiyuHome
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to history")

                    Spacer()
                }

                Text("Your choices")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .tracking(-1)

                if let session {
                    Text(session.feeling)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryInk)

                    ForEach(Array(session.answers.enumerated()), id: \.element.id) { index, record in
                        VStack(alignment: .leading, spacing: 14) {
                            if shouldShowSetTitle(at: index, in: session.answers) {
                                Text(setTitle(for: record))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.ink)
                                    .padding(.top, index == 0 ? 4 : 18)
                            }

                            Text(record.opening)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryInk)
                                .lineSpacing(3)

                            summaryChoice(
                                key: "\(record.id)-qiyu",
                                label: responseLabel(
                                    for: .qiyu,
                                    receiver: session.receiver ?? .qiyu
                                ),
                                scenario: firstScenario(for: record)
                            )

                            summaryChoice(
                                key: "\(record.id)-samar",
                                label: responseLabel(
                                    for: .samar,
                                    receiver: session.receiver ?? .qiyu
                                ),
                                scenario: secondScenario(for: record)
                            )
                        }
                        .padding(.vertical, 14)
                    }

                    if let experiment = session.experiment {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TRY NEXT")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.secondaryInk)

                            Text(experiment)
                                .font(.body)
                                .foregroundStyle(Color.primary)
                        }
                        .padding()
                        .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Button {
                        let summary = AISessionSummary.make(from: session)
                        appState.saveSuggestedInsights(summary.profileSuggestions)
                        showingAISummary = true
                    } label: {
                        Label("View AI suggested summary", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .controlSize(.large)
                    .tint(AppTheme.ink)
                }

                Button("New reflection") {
                    appState.startNewReflection()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingAISummary) {
            if let session {
                AISuggestedSummaryView(summary: .make(from: session))
            }
        }
    }

    private func responseLabel(
        for person: Perspective,
        receiver: Perspective
    ) -> String {
        person == receiver
            ? "\(person.rawValue) would feel good with"
            : "\(person.rawValue) could comfortably do"
    }

    private func firstScenario(for record: RoundAnswerRecord) -> Scenario {
        record.qiyuChoice
    }

    private func secondScenario(for record: RoundAnswerRecord) -> Scenario {
        record.samarPrediction
    }

    private func shouldShowSetTitle(
        at index: Int,
        in records: [RoundAnswerRecord]
    ) -> Bool {
        guard index > 0 else { return true }
        return setTitle(for: records[index]) != setTitle(for: records[index - 1])
    }

    private func setTitle(for record: RoundAnswerRecord) -> String {
        let id = record.id

        if id.contains("advance-notice")
            || id.contains("who-asks-first")
            || id.contains("busy-week-boundary")
            || id.contains("shared-time-rhythm")
            || id.contains("weekend-social-allocation")
            || id.contains("weekend-protected-time") {
            return "Making space"
        }

        if id.contains("plan-changes")
            || id.contains("busy-day-update")
            || id.contains("response-timing") {
            return "When plans meet work"
        }

        if id.contains("sharing-small-joy")
            || id.contains("good-news")
            || id.contains("support-after-hard-day")
            || id.contains("physical-reconnection") {
            return "Joining each other’s moments"
        }

        if id.contains("conflict-first-step")
            || id.contains("repair-next-step")
            || id.contains("pause-and-return") {
            return "Repair and return"
        }

        return "More to understand"
    }

    private func summaryChoice(key: String, label: String, scenario: Scenario) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedAnswer = expandedAnswer == key ? nil : key
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .tracking(0.6)
                        Text(scenario.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: expandedAnswer == key ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                if expandedAnswer == key {
                    Text(scenario.body)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineSpacing(3)
                        .padding(.top, 4)
                }
            }
            .padding(18)
            .background(.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AISuggestedSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let summary: AISessionSummary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Based on this session")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)

                        Text("Observations are kept separate from AI hypotheses. The hypotheses are saved to each person’s profile as “To explore.”")
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                            .lineSpacing(3)
                    }

                    summarySection(
                        title: "What each person selected",
                        icon: "checkmark.circle",
                        items: summary.observations
                    )

                    summarySection(
                        title: "Where understanding differed",
                        icon: "arrow.left.arrow.right",
                        items: summary.comparisons
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Patterns to check", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)

                        ForEach(summary.hypotheses) { hypothesis in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(hypothesis.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)

                                Text(hypothesis.detail)
                                    .font(.body)
                                    .foregroundStyle(Color.primary)
                                    .lineSpacing(3)

                                Text(hypothesis.evidence)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                                    .lineSpacing(2)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
                .padding(24)
            }
            .background(AppTheme.page)
            .navigationTitle("AI suggested summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func summarySection(
        title: String,
        icon: String,
        items: [AISummaryItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(item.detail)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            }
        }
    }
}

private struct AISummaryItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct AIHypothesis: Identifiable {
    let id = UUID()
    let person: Perspective
    let kind: ProfileInsightKind
    let title: String
    let detail: String
    let evidence: String
}

private struct AISessionSummary {
    let observations: [AISummaryItem]
    let comparisons: [AISummaryItem]
    let hypotheses: [AIHypothesis]

    var profileSuggestions: [ProfileInsightSuggestion] {
        hypotheses.map {
            ProfileInsightSuggestion(
                person: $0.person,
                kind: $0.kind,
                statement: $0.detail,
                evidence: $0.evidence
            )
        }
    }

    static func make(from session: SavedSession) -> AISessionSummary {
        let receiver = session.receiver ?? .qiyu
        let actor = receiver.partner

        let observations = session.answers.map { record in
            return AISummaryItem(
                title: "What each person chose",
                detail: "For “\(shortContext(record.opening)),” Qiyu chose “\(record.qiyuChoice.title)” and Samar chose “\(record.samarPrediction.title).”"
            )
        }

        let comparisons = session.answers.map { record in
            let receiverChoice = receiver == .qiyu
                ? record.qiyuChoice
                : record.samarPrediction
            let actorChoice = actor == .qiyu
                ? record.qiyuChoice
                : record.samarPrediction

            if record.matches {
                return AISummaryItem(
                    title: "An overlap",
                    detail: "\(receiver.rawValue) would feel good receiving “\(receiverChoice.title),” and \(actor.rawValue) said they could comfortably do it."
                )
            }

            return AISummaryItem(
                title: "A gap to talk about",
                detail: "\(receiver.rawValue) would feel good receiving “\(receiverChoice.title),” while \(actor.rawValue) felt more comfortable with “\(actorChoice.title).”"
            )
        }

        let hypotheses = session.answers.map { record in
            hypothesis(for: record, receiver: receiver)
        }

        return AISessionSummary(
            observations: observations,
            comparisons: comparisons,
            hypotheses: hypotheses
        )
    }

    private static func hypothesis(
        for record: RoundAnswerRecord,
        receiver: Perspective
    ) -> AIHypothesis {
        let actual = receiver == .qiyu ? record.qiyuChoice : record.samarPrediction
        let baseEvidence = "In “\(shortContext(record.opening)),” \(receiver.rawValue) selected “\(actual.title).”"

        if record.id.contains("generated-") {
            return AIHypothesis(
                person: receiver,
                kind: .sustainableAction,
                title: "A concrete response is worth checking again",
                detail: "\(receiver.rawValue) selected “\(actual.title)” as something that could feel helpful in this situation.",
                evidence: baseEvidence + " This is one contextual choice, not a permanent preference."
            )
        }

        switch actual.id {
        case "early-update", "later-review", "early-tentative":
            return AIHypothesis(
                person: .qiyu,
                kind: .sustainableAction,
                title: "How planning begins may matter while work is unresolved",
                detail: "Qiyu may prefer Samar to initiate either a future update or a possible time before all of the work details are settled.",
                evidence: baseEvidence + " This comparison varies what starts the planning process while weekend availability remains uncertain."
            )
        case "respond-after-ask":
            return AIHypothesis(
                person: .qiyu,
                kind: .sustainableAction,
                title: "A response after a direct question may be enough in this moment",
                detail: "Qiyu selected the version where her question prompts Samar to review the situation and share what he knows.",
                evidence: baseEvidence + " This should be checked against situations where no question is sent."
            )
        case "samar-asks":
            return AIHypothesis(
                person: .qiyu,
                kind: .connection,
                title: "Who starts the plan may carry information",
                detail: "Qiyu may experience a plan differently when Samar raises it before being asked.",
                evidence: baseEvidence + " The available time stays the same; who sends the first planning message changes."
            )
        case "sunset-join":
            return AIHypothesis(
                person: .qiyu,
                kind: .connection,
                title: "Attention to Qiyu’s experience may matter",
                detail: "Qiyu may prefer a reply that asks what the moment was like for her rather than focusing only on the photograph.",
                evidence: baseEvidence + " The same photo is shown; the target of Samar’s attention changes."
            )
        case "sunset-sharing":
            return AIHypothesis(
                person: .qiyu,
                kind: .connection,
                title: "The act of sharing may carry meaning",
                detail: "Qiyu may prefer a reply that notices her choice to send the moment to Samar.",
                evidence: baseEvidence + " The same photo is shown; the target of Samar’s attention changes."
            )
        case "busy-update-morning":
            return AIHypothesis(
                person: .qiyu,
                kind: .communication,
                title: "A short update may work differently before silence",
                detail: "Qiyu may prefer receiving a short update before Samar becomes unavailable for the workday.",
                evidence: baseEvidence + " Both versions contain one Samar-initiated message; whether it arrives before or after work changes."
            )
        case "busy-update-evening":
            return AIHypothesis(
                person: .qiyu,
                kind: .communication,
                title: "Reconnecting after work may be enough in this moment",
                detail: "Qiyu may prefer Samar to focus on work and initiate a conversation once he is available again.",
                evidence: baseEvidence + " Both versions contain one Samar-initiated message; whether it arrives before or after work changes."
            )
        case "support-listen":
            return AIHypothesis(
                person: .qiyu,
                kind: .communication,
                title: "Listening may be the first useful response",
                detail: "Qiyu may prefer being invited to explain a difficult day before Samar proposes an action.",
                evidence: baseEvidence + " This is specific to the support scenario and should be checked in other contexts."
            )
        case "support-practical":
            return AIHypothesis(
                person: .qiyu,
                kind: .communication,
                title: "A concrete offer may make support easier to receive",
                detail: "Qiyu may prefer Samar to offer one practical next step instead of beginning with a longer conversation.",
                evidence: baseEvidence + " This is specific to the support scenario and should be checked in other contexts."
            )
        case "support-quiet":
            return AIHypothesis(
                person: .qiyu,
                kind: .communication,
                title: "Quiet company may be a form of support",
                detail: "Qiyu may prefer shared low-demand time before talking through a difficult day.",
                evidence: baseEvidence + " This is specific to the support scenario and should be checked in other contexts."
            )
        case "conflict-impact-first":
            return AIHypothesis(
                person: .qiyu,
                kind: .communication,
                title: "Impact may need to be heard before solutions",
                detail: "Qiyu may prefer the first conflict response to acknowledge what happened and its effect before discussing a fix.",
                evidence: baseEvidence + " Both versions address the same conflict; the order of the response changes."
            )
        case "conflict-solution-first":
            return AIHypothesis(
                person: .qiyu,
                kind: .communication,
                title: "Work context may be easier to hear first",
                detail: "Qiyu may prefer Samar to explain the concrete work change before asking about its emotional impact.",
                evidence: baseEvidence + " Both versions include context and impact; only their order changes."
            )
        case "pause-with-return":
            return AIHypothesis(
                person: .qiyu,
                kind: .sustainableAction,
                title: "A pause may feel different when it includes a return time",
                detail: "Qiyu may be more comfortable pausing a difficult conversation when both people name when they will resume it.",
                evidence: baseEvidence + " Both versions pause; only the explicit return point changes."
            )
        case "shared-eight-hours", "shared-four-hours":
            return AIHypothesis(
                person: .qiyu,
                kind: .constraint,
                title: "The preferred amount of shared time can be discussed concretely",
                detail: "Qiyu selected “\(actual.title)” for this weekend scenario; that duration is a testable reference point, not a permanent rule.",
                evidence: baseEvidence + " Compare the chosen hours, start time, and amount of separate time rather than using “more closeness” or “more independence.”"
            )
        default:
            return AIHypothesis(
                person: .qiyu,
                kind: .connection,
                title: "One scenario provides a concrete hypothesis",
                detail: "Qiyu’s selection suggests that “\(actual.title)” is worth testing in a similar real situation.",
                evidence: baseEvidence + " One choice is not enough to infer a stable preference."
            )
        }
    }

    private static func shortContext(_ opening: String) -> String {
        let firstSentence = opening.split(separator: ".").first.map(String.init) ?? opening
        return firstSentence.count > 90
            ? String(firstSentence.prefix(87)) + "…"
            : firstSentence
    }
}

struct CoDesignView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var experimentIsFocused: Bool

    private let proposedExperiment = """
    By Tuesday, suggest one possible time for the weekend. It can stay tentative until Thursday. If that time changes, suggest one other time.
    """

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Try one small thing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.ink)

                Text("This combines the early signal Qiyu compared with the flexibility Samar compared.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Label("One-week experiment", systemImage: "calendar.badge.clock")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    TextEditor(text: $appState.sharedExperiment)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .scrollContentBackground(.hidden)
                        .focused($experimentIsFocused)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    experimentIsFocused ? AppTheme.accent : Color(.separator),
                                    lineWidth: experimentIsFocused ? 2 : 1
                                )
                        }
                }
                .padding()
                .background(AppTheme.accentSoft.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text("Edit any detail until both people could realistically try it.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)

                Button {
                    appState.finishSession()
                } label: {
                    Label("Save this conversation", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .tint(AppTheme.ink)
                .disabled(appState.sharedExperiment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Save without an experiment") {
                    appState.sharedExperiment = ""
                    appState.finishSession()
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if appState.sharedExperiment.isEmpty {
                appState.sharedExperiment = proposedExperiment
            }
        }
    }
}

struct QiyuHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedMode: ScenarioSourceMode = .curated

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Question source", selection: $selectedMode) {
                    ForEach(ScenarioSourceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                if selectedMode == .curated {
                    curatedHome
                } else {
                    adaptiveHome
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.stage = .perspective
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.openProfiles(returningTo: .qiyuHome)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .onAppear {
                selectedMode = appState.scenarioSourceMode
            }
        }
    }

    private var curatedHome: some View {
        Group {
            if appState.reflectionOwner == .samar {
                samarHardcodedHome
            } else {
                curatedHistoryHome
            }
        }
    }

    private var curatedHistoryHome: some View {
        ZStack(alignment: .bottomTrailing) {
            if appState.savedSessions.isEmpty {
                ContentUnavailableView(
                    "No conversations yet",
                    systemImage: "person.2",
                    description: Text("Start with a moment or a question you want to explore together.")
                )
            } else {
                List {
                    ForEach(appState.savedSessions) { session in
                        Button {
                            appState.openSession(session)
                        } label: {
                            SessionHistoryRow(session: session)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 16))
                        .listRowBackground(Color(.systemBackground))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 88, for: .scrollContent)
                .background(Color(.systemBackground))
            }

            Button {
                appState.startNewReflection(mode: .curated)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(AppTheme.ink)
            .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
            .padding(.trailing, 22)
            .padding(.bottom, 20)
            .accessibilityLabel("New curated conversation")
        }
    }

    private var samarHardcodedHome: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Pick a question to try")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.ink)
                    .padding(.bottom, 4)

                Text("These saved sets use the same scenarios every time, so you can review and refine the wording.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .padding(.bottom, 8)

                ForEach(appState.suggestedQuestions, id: \.question) { item in
                    Button {
                        appState.startHardcodedQuestion(item.question)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.label)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                Text(item.question)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryInk)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 12)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppTheme.divider, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    appState.startNewReflection(mode: .curated)
                } label: {
                    Label("Write a different question", systemImage: "square.and.pencil")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .tint(AppTheme.ink)
                .padding(.top, 8)
            }
            .padding(24)
        }
    }

    private var adaptiveHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Generated for this conversation", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text("Start with your words")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.ink)

                    Text("On-device AI uses what \(appState.reflectionOwner.rawValue) types and both saved profiles to write new, concrete comparisons. The text stays on this device.")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineSpacing(4)
                }
                .padding(22)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 16) {
                    adaptiveStep("1", "You describe a moment or type a question.")
                    adaptiveStep("2", "AI writes neutral moments that change one behavior at a time.")
                    adaptiveStep("3", "\(appState.reflectionOwner.rawValue) chooses what feels good; \(appState.reflectionOwner.partner.rawValue) chooses what feels realistic.")
                    adaptiveStep("4", "The next comparison looks for a workable bridge.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("On-device model")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Label(
                        appState.onDeviceAIStatus,
                        systemImage: appState.isOnDeviceAIAvailable
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        appState.isOnDeviceAIAvailable
                            ? Color.green
                            : AppTheme.secondaryInk
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    Text(
                        appState.isOnDeviceAIAvailable
                            ? "No API key or network connection is used."
                            : "You can still preview the adaptive flow here. A supported physical device will generate new language on-device."
                    )
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                .padding(18)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    appState.startNewReflection(mode: .adaptive)
                } label: {
                    HStack {
                        Text("Generate new scenarios")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .tint(AppTheme.ink)
            }
            .padding(24)
        }
    }

    private func adaptiveStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(AppTheme.accent)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SessionHistoryRow: View {
    let session: SavedSession

    var body: some View {
        HStack(spacing: 14) {
            SessionThumbnail()

            VStack(alignment: .leading, spacing: 4) {
                Text(session.feeling)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                Label(
                    "\(session.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(session.answers.count) questions",
                    systemImage: "person.2"
                )
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this saved conversation")
    }
}

private struct SessionThumbnail: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 1, green: 0.72, blue: 0.08)

                Ellipse()
                    .fill(AppTheme.accent)
                    .frame(width: proxy.size.width * 1.45, height: proxy.size.height * 0.68)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.92)

                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.ink.opacity(0.8))
                    .offset(y: 7)
            }
        }
        .frame(width: 74, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
    }
}
