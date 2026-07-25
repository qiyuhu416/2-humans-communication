import SwiftUI

struct RevealView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var deepDiveIsOpen = false
    @State private var pullDistance: CGFloat = 0
    @State private var expandedChoice: String?

    private let questionProvider: DiscussionQuestionProviding = LocalDiscussionQuestionProvider()
    private let revealThreshold: CGFloat = 110

    private var qiyuResponse: Scenario? {
        appState.currentRound.scenarios.first { $0.id == appState.qiyuChoiceID }
    }

    private var samarResponse: Scenario? {
        appState.currentRound.scenarios.first { $0.id == appState.samarPredictionID }
    }

    private var actualScenario: Scenario? {
        appState.currentRound.focusPerspective == .qiyu ? qiyuResponse : samarResponse
    }

    private var predictedScenario: Scenario? {
        appState.currentRound.focusPerspective == .qiyu ? samarResponse : qiyuResponse
    }

    private var actualLabel: String {
        appState.currentRound.focusPerspective.rawValue
    }

    private var predictionLabel: String {
        appState.currentRound.focusPerspective == .qiyu ? "Samar’s guess" : "Qiyu’s guess"
    }

    private var hasNextRound: Bool {
        appState.currentRoundIndex + 1 < appState.rounds.count
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LayeredWarmBackground()

                answerContent

                deepDiveSheet(in: proxy.size)
            }
        }
        .onAppear {
            appState.recordCurrentRoundIfNeeded()
        }
    }

    private var answerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 7) {
                        Text("Both answers")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryInk)

                        Text(appState.answersMatch ? "Same" : "Different")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    Button {
                        appState.finishSession()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(AppTheme.ink)
                    .accessibilityLabel("Exit questions")
                }

                Text(appState.currentRound.opening)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)

                VStack(spacing: 12) {
                    if let actualScenario {
                        ExpandableAnswerRow(
                            key: "actual",
                            label: actualLabel,
                            scenario: actualScenario,
                            expandedChoice: $expandedChoice
                        )
                    }

                    if let predictedScenario {
                        ExpandableAnswerRow(
                            key: "prediction",
                            label: predictionLabel,
                            scenario: predictedScenario,
                            expandedChoice: $expandedChoice
                        )
                    }
                }
                .padding(.top, 22)

                nextButton
                    .padding(.top, 18)
                    .padding(.bottom, 210)
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    private func deepDiveSheet(in size: CGSize) -> some View {
        let restingOffset = max(240, size.height - 150)
        let currentOffset = deepDiveIsOpen
            ? CGFloat.zero
            : max(0, restingOffset - pullDistance)

        return ZStack(alignment: .top) {
            RoundedRectangle(
                cornerRadius: deepDiveIsOpen ? 48 : size.width / 2,
                style: .continuous
            )
                .fill(deepDiveIsOpen ? AppTheme.page : AppTheme.accent)
                .ignoresSafeArea(edges: .bottom)

            if deepDiveIsOpen {
                deepDiveContent
                    .transition(.opacity)
            } else {
                deepDiveHandle
                    .transition(.opacity)
                    .contentShape(Rectangle())
                    .gesture(deepDiveGesture)
            }
        }
        .frame(width: size.width, height: size.height)
        .offset(y: currentOffset)
        .animation(
            reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.48, dampingFraction: 0.86),
            value: deepDiveIsOpen
        )
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.88), value: pullDistance)
    }

    private var deepDiveHandle: some View {
        VStack(spacing: 9) {
            Image(systemName: pullDistance >= revealThreshold ? "arrow.up.circle.fill" : "arrow.up")
                .font(.title2)
                .foregroundStyle(AppTheme.secondaryInk)
                .symbolEffect(.pulse, options: .repeating)

            Text(deepDiveHint)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Swipe up for more questions")
    }

    private var deepDiveHint: String {
        if pullDistance >= revealThreshold {
            return "Release for more questions"
        }
        if pullDistance > 36 {
            return "Keep going"
        }
        return "Swipe up for more questions"
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
                HStack {
                    Capsule()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 36, height: 5)

                    Spacer()

                    Button {
                        withAnimation {
                            deepDiveIsOpen = false
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .accessibilityLabel("Close more questions")
                }

                Text("More questions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.ink)

                Text(appState.currentRound.opening)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)

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

                nextButton
                    .padding(.top, 18)
                    .padding(.bottom, 34)
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    private var nextButton: some View {
        Button(action: moveForward) {
            Label(
                hasNextRound ? "Next question" : "Find the overlap",
                systemImage: "arrow.right"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
        .tint(AppTheme.ink)
    }

    private var suggestedQuestions: [String] {
        questionProvider.questions(
            for: appState.currentRound,
            selectedScenarioID: appState.qiyuChoiceID
        )
    }

    private func moveForward() {
        if hasNextRound {
            appState.startNextRound()
        } else {
            appState.stage = .coDesign
        }
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
                            .textCase(.uppercase)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
