import SwiftUI

struct ScenarioSplitView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var orangeSurfaceHasMoved = false
    @State private var cardsAreVisible = false
    @State private var showingExitConfirmation = false

    var body: some View {
        GeometryReader { proxy in
            // The center divider also owns the exit control. Keep it tall enough
            // for the control to read as part of the bar rather than floating
            // between the two participant panels.
            let dividerHeight: CGFloat = 40
            let panelHeight = max(0, (proxy.size.height - dividerHeight) / 2)

            ZStack {
                AppTheme.questionBackground

                VStack(spacing: 0) {
                    ParticipantScenarioPanel(
                        question: qiyuQuestionText,
                        scenarios: appState.currentRound.scenarios,
                        selection: $appState.qiyuChoiceID,
                        isLocked: $appState.qiyuLocked,
                        otherPersonIsReady: appState.samarLocked,
                        answerRole: appState.reflectionOwner == .qiyu ? .receiving : .doing,
                        isVisible: cardsAreVisible,
                        reveal: reveal
                    )
                    .rotationEffect(.degrees(180))
                    .frame(height: panelHeight)

                    Rectangle()
                        .fill(AppTheme.accent)
                        .frame(height: dividerHeight)
                        .accessibilityHidden(true)

                    ParticipantScenarioPanel(
                        question: samarQuestionText,
                        scenarios: Array(appState.currentRound.scenarios.reversed()),
                        selection: $appState.samarPredictionID,
                        isLocked: $appState.samarLocked,
                        otherPersonIsReady: appState.qiyuLocked,
                        answerRole: appState.reflectionOwner == .samar ? .receiving : .doing,
                        isVisible: cardsAreVisible,
                        reveal: reveal
                    )
                    .frame(height: panelHeight)
                }

                // The orange surface from the story opening continues into this
                // screen, then travels upward. The divider is already underneath,
                // so it is naturally uncovered as the surface clears the center.
                Rectangle()
                    .fill(AppTheme.accent)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(
                        y: orangeSurfaceHasMoved
                            ? -(proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                            : 0
                    )
                    .shadow(
                        color: Color.black.opacity(orangeSurfaceHasMoved ? 0 : 0.08),
                        radius: 12,
                        x: 0,
                        y: 8
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .trailing) {
                    Button {
                        showingExitConfirmation = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: dividerHeight, height: dividerHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.trailing, 2)
                    .accessibilityLabel("Exit questions")
                }
            .ignoresSafeArea()
            .onAppear {
                let surfaceAnimation: Animation = reduceMotion
                    ? .linear(duration: 0.01)
                    : .timingCurve(0.42, 0, 0.18, 1, duration: 0.82)

                withAnimation(surfaceAnimation) {
                    orangeSurfaceHasMoved = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.01 : 0.42)) {
                    let cardAnimation: Animation = reduceMotion
                        ? .linear(duration: 0.01)
                        : .spring(response: 0.48, dampingFraction: 0.9)

                    withAnimation(cardAnimation) {
                        cardsAreVisible = true
                    }
                }
            }
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
    }

    private func reveal() {
        appState.stage = .reveal
    }

    private var qiyuQuestionText: String {
        "\(appState.currentRound.opening)\n\n\(appState.currentRound.qiyuPrompt)"
    }

    private var samarQuestionText: String {
        "\(appState.currentRound.opening)\n\n\(appState.currentRound.samarPrompt)"
    }
}

private enum AnswerRole {
    case receiving
    case doing
}

private struct ParticipantScenarioPanel: View {
    let question: String
    let scenarios: [Scenario]
    @Binding var selection: String?
    @Binding var isLocked: Bool
    let otherPersonIsReady: Bool
    let answerRole: AnswerRole
    let isVisible: Bool
    let reveal: () -> Void

    @State private var currentScenarioID: String?
    @State private var showsQuestion = false

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                if showsQuestion {
                    QuestionReminderText(question: question)
                        .transition(.opacity)
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 14) {
                            ForEach(scenarios) { scenario in
                                ScenarioChoiceCard(
                                    scenario: scenario,
                                    selected: selection == scenario.id,
                                    disabled: isLocked
                                ) {
                                    selection = scenario.id
                                }
                                .frame(width: max(220, proxy.size.width - 84))
                                .id(scenario.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 42, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $currentScenarioID)
                    .scrollIndicators(.hidden)
                    .scrollDisabled(isLocked)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showsQuestion.toggle()
                    }
                } label: {
                    Image(systemName: showsQuestion ? "rectangle.stack" : "text.page")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .controlSize(.regular)
                .tint(Color(.secondaryLabel))
                .accessibilityLabel(showsQuestion ? "View answer choices" : "View question")
                .accessibilityHint(
                    showsQuestion
                        ? "Returns to the answer choices on your side"
                        : "Shows the question on your side only"
                )

                AnswerActionButton(
                    hasSelection: selection != nil,
                    isLocked: isLocked,
                    otherPersonIsReady: otherPersonIsReady,
                    answerRole: answerRole
                ) {
                    guard selection != nil else { return }
                    isLocked = true

                    if otherPersonIsReady {
                        reveal()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.96)
        .allowsHitTesting(isVisible)
        .onAppear {
            currentScenarioID = scenarios.first?.id
        }
        .onChange(of: scenarios.first?.id) {
            currentScenarioID = scenarios.first?.id
        }
    }
}

private struct QuestionReminderText: View {
    let question: String

    var body: some View {
        ScrollView {
            Text(question)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.ink)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 18)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Question: \(question)")
    }
}

private struct AnswerActionButton: View {
    let hasSelection: Bool
    let isLocked: Bool
    let otherPersonIsReady: Bool
    let answerRole: AnswerRole
    let action: () -> Void

    private var title: String {
        if isLocked { return "Ready" }
        if otherPersonIsReady { return "See both" }
        return answerRole == .receiving ? "I’d feel good with this" : "I could do this"
    }

    private var symbol: String {
        if isLocked { return "checkmark" }
        if otherPersonIsReady { return "eye" }
        return "checkmark"
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .controlSize(.regular)
        .tint(AppTheme.ink)
        .disabled(!hasSelection || isLocked)
    }
}

private struct ScenarioChoiceCard: View {
    let scenario: Scenario
    let selected: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    Text(scenario.body)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 30)
                }
                .scrollIndicators(.automatic)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AppTheme.accent : Color(.tertiaryLabel))
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                selected
                    ? AppTheme.accentSoft.opacity(0.72)
                    : Color(.systemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(
                color: Color.black.opacity(selected ? 0.08 : 0.06),
                radius: selected ? 8 : 8,
                x: 0,
                y: 2
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        selected
                            ? AppTheme.accent.opacity(0.32)
                            : Color(.separator).opacity(0.2),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .animation(.easeInOut(duration: 0.18), value: selected)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(scenario.body)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to select this scenario")
    }
}
