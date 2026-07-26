import SwiftUI

struct RevealView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var deepDiveIsOpen = false
    @State private var pullDistance: CGFloat = 0
    @State private var expandedChoice: String?
    @State private var showingExitConfirmation = false
    @State private var contentScrollOffset: CGFloat = 0

    private let questionProvider: DiscussionQuestionProviding = LocalDiscussionQuestionProvider()
    private let revealThreshold: CGFloat = 110

    private var qiyuResponse: Scenario? {
        appState.currentRound.scenarios.first { $0.id == appState.qiyuChoiceID }
    }

    private var samarResponse: Scenario? {
        appState.currentRound.scenarios.first { $0.id == appState.samarPredictionID }
    }

    private var unchosenResponses: [Scenario] {
        guard appState.answersMatch, let selectedID = appState.qiyuChoiceID else {
            return []
        }
        return appState.currentRound.scenarios.filter { $0.id != selectedID }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                revealBackground(in: proxy.size, scrollOffset: contentScrollOffset)

                answerContent(in: proxy.size)

                exitButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .zIndex(10)

                if !deepDiveIsOpen {
                    deepDiveSheet(in: proxy.size)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            appState.recordCurrentRoundIfNeeded()
        }
        .sheet(isPresented: $deepDiveIsOpen) {
            deepDiveContent
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemBackground))
        }
        .animation(.easeInOut(duration: 0.22), value: deepDiveIsOpen)
        .confirmationDialog(
            "Leave this conversation?",
            isPresented: $showingExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave conversation", role: .destructive) {
                appState.finishSession()
            }
            Button("Keep talking", role: .cancel) {}
        } message: {
            Text("Your completed answers will be saved.")
        }
    }

    private func answerContent(in size: CGSize) -> some View {
        let followUpArcHeight = AppTheme.swipeArcVisibleHeight(for: size.height)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: RevealScrollOffsetKey.self,
                        value: proxy.frame(in: .named("reveal-scroll")).minY
                    )
                }
                .frame(height: 0)

                Spacer(minLength: 70)

                VStack(alignment: .leading, spacing: 0) {
                    Text(
                        appState.answersMatch
                            ? "This works for both of you"
                            : "Here’s the gap"
                    )
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)

                    Text(appState.currentRound.opening)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.ink)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 30)

                    VStack(spacing: 12) {
                        if let qiyuResponse {
                            ExpandableAnswerRow(
                                key: "qiyu",
                                label: responseLabel(for: .qiyu),
                                scenario: qiyuResponse,
                                expandedChoice: $expandedChoice
                            )
                        }

                        if let samarResponse {
                            ExpandableAnswerRow(
                                key: "samar",
                                label: responseLabel(for: .samar),
                                scenario: samarResponse,
                                expandedChoice: $expandedChoice
                            )
                        }

                        ForEach(Array(unchosenResponses.enumerated()), id: \.element.id) { index, scenario in
                            ExpandableAnswerRow(
                                key: "unchosen-\(scenario.id)",
                                label: unchosenResponses.count == 1
                                    ? "The unchosen answer"
                                    : "Unchosen answer \(index + 1)",
                                scenario: scenario,
                                expandedChoice: $expandedChoice
                            )
                        }
                    }
                    .padding(.top, 36)
                }

                navigationArrows
                    .frame(maxWidth: .infinity)
                    .padding(.top, 34)

                Spacer(minLength: followUpArcHeight + 26)
            }
            .frame(minHeight: size.height)
            .padding(.horizontal, 28)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "reveal-scroll")
        .onPreferenceChange(RevealScrollOffsetKey.self) { value in
            contentScrollOffset = max(0, -value)
        }
    }

    private var exitButton: some View {
        Button {
            showingExitConfirmation = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.ink)
        .accessibilityLabel("Exit questions")
    }

    private func deepDiveSheet(in size: CGSize) -> some View {
        let followUpArcHeight = AppTheme.swipeArcVisibleHeight(for: size.height)
        let restingOffset = max(240, size.height - followUpArcHeight)
        let currentOffset = max(0, restingOffset - pullDistance)

        return ZStack(alignment: .top) {
            CurvedTopArc(depth: AppTheme.swipeArcRestingDepth)
                .fill(AppTheme.accent)
                .ignoresSafeArea(edges: .bottom)

            deepDiveHandle(height: followUpArcHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    deepDiveIsOpen = true
                }
                .gesture(deepDiveGesture)
        }
        .frame(width: size.width, height: size.height)
        .offset(y: currentOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.88), value: pullDistance)
    }

    private func deepDiveHandle(height: CGFloat) -> some View {
        SwipeUpHandle(
            pullDistance: pullDistance,
            threshold: revealThreshold,
            destination: "follow-up questions",
            height: height
        )
    }

    private func revealBackground(in size: CGSize, scrollOffset: CGFloat) -> some View {
        let progress = min(max(scrollOffset / 120, 0), 1)
        let restingOffset = size.height * 0.15
        let filledOffset: CGFloat = -28
        let yellowOffset = restingOffset + (filledOffset - restingOffset) * progress

        return ZStack(alignment: .top) {
            AppTheme.page

            CurvedTopArc(depth: 28)
                .fill(Color(red: 1.0, green: 0.96, blue: 0.82))
                .frame(width: size.width, height: size.height)
                .offset(y: yellowOffset)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var deepDiveGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                pullDistance = max(0, -value.translation.height)
            }
            .onEnded { value in
                let projectedPull = max(pullDistance, -value.predictedEndTranslation.height)

                if projectedPull >= revealThreshold {
                    withAnimation {
                        pullDistance = 0
                        deepDiveIsOpen = true
                    }
                } else {
                    withAnimation {
                        pullDistance = 0
                    }
                }
            }
    }

    private var deepDiveContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Keep talking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.ink)

                Text(appState.currentRound.opening)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)

                VStack(alignment: .leading, spacing: 14) {
                    Label("A few places to go next", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    ForEach(Array(suggestedQuestions.enumerated()), id: \.offset) { index, question in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 28, height: 28)
                                .background(AppTheme.accentSoft)
                                .clipShape(Circle())

                            Text(question)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.ink)
                        }
                    }
                }
                .padding(18)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Divider()

                AIRationaleContent(
                    round: appState.currentRound,
                    sourceQuestion: appState.feeling
                )

                navigationArrows
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    private var navigationArrows: some View {
        HStack {
            Button {
                appState.stage = .qiyuScenario
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to answers")

            Spacer()

            Button {
                Task { await appState.startNextRound() }
            } label: {
                Group {
                    if appState.isPreparingNextRound {
                        ProgressView()
                            .tint(AppTheme.ink)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                .frame(width: 58, height: 58)
            }
            .buttonStyle(.plain)
            .disabled(appState.isPreparingNextRound)
            .accessibilityLabel("Next question")
        }
    }

    private var suggestedQuestions: [String] {
        questionProvider.questions(
            for: appState.currentRound,
            selectedScenarioID: appState.qiyuChoiceID
        )
    }

    private func responseLabel(for person: Perspective) -> String {
        person == appState.reflectionOwner
            ? "\(person.rawValue) would feel good with"
            : "\(person.rawValue) could comfortably do"
    }

}

private struct RevealScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ExpandableAnswerRow: View {
    let key: String
    let label: String
    let scenario: Scenario
    @Binding var expandedChoice: String?

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedChoice = expandedChoice == key ? nil : key
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.secondaryInk)

                        Text(scenario.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                    }

                    Spacer()

                    Image(systemName: expandedChoice == key ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color(.tertiaryLabel))
                }

                if expandedChoice == key {
                    Text(scenario.body)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .lineSpacing(4)
                        .padding(.top, 2)
                }
            }
            .padding()
            .frame(minHeight: 100)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.045), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}
