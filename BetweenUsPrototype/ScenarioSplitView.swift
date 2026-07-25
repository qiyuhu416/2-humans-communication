import SwiftUI

struct ScenarioSplitView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var backgroundHasLightened = false
    @State private var cardsAreVisible = false

    var body: some View {
        GeometryReader { proxy in
            let panelHeight = max(0, (proxy.size.height - 1) / 2)

            ZStack {
                AppTheme.accent

                AppTheme.questionBackground
                    .opacity(backgroundHasLightened ? 1 : 0)

                VStack(spacing: 0) {
                    ParticipantScenarioPanel(
                        scenarios: appState.currentRound.scenarios,
                        selection: $appState.qiyuChoiceID,
                        isLocked: $appState.qiyuLocked,
                        otherPersonIsReady: appState.samarLocked,
                        answerRole: appState.currentRound.focusPerspective == .qiyu ? .actual : .prediction,
                        isVisible: cardsAreVisible,
                        reveal: reveal
                    )
                    .rotationEffect(.degrees(180))
                    .frame(height: panelHeight)

                    Divider()
                        .overlay(Color(.separator).opacity(0.45))

                    ParticipantScenarioPanel(
                        scenarios: Array(appState.currentRound.scenarios.reversed()),
                        selection: $appState.samarPredictionID,
                        isLocked: $appState.samarLocked,
                        otherPersonIsReady: appState.qiyuLocked,
                        answerRole: appState.currentRound.focusPerspective == .samar ? .actual : .prediction,
                        isVisible: cardsAreVisible,
                        reveal: reveal
                    )
                    .frame(height: panelHeight)
                }
                .overlay(alignment: .trailing) {
                    Button {
                        appState.finishSession()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.trailing, 6)
                    .accessibilityLabel("Exit questions")
                }
            }
            .ignoresSafeArea()
            .onAppear {
                let backgroundAnimation: Animation = reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 0.48)

                withAnimation(backgroundAnimation) {
                    backgroundHasLightened = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.01 : 0.34)) {
                    let cardAnimation: Animation = reduceMotion
                        ? .linear(duration: 0.01)
                        : .spring(response: 0.44, dampingFraction: 0.88)

                    withAnimation(cardAnimation) {
                        cardsAreVisible = true
                    }
                }
            }
        }
    }

    private func reveal() {
        appState.stage = .reveal
    }
}

private enum AnswerRole {
    case actual
    case prediction
}

private struct ParticipantScenarioPanel: View {
    let scenarios: [Scenario]
    @Binding var selection: String?
    @Binding var isLocked: Bool
    let otherPersonIsReady: Bool
    let answerRole: AnswerRole
    let isVisible: Bool
    let reveal: () -> Void

    @State private var currentScenarioID: String?

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack {
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

                    HStack {
                        CarouselArrow(
                            systemName: "chevron.left",
                            disabled: isLocked
                        ) {
                            move(by: -1)
                        }

                        Spacer()

                        CarouselArrow(
                            systemName: "chevron.right",
                            disabled: isLocked
                        ) {
                            move(by: 1)
                        }
                    }
                    .padding(.horizontal, 4)
                    .allowsHitTesting(!isLocked)
                }
            }
            .frame(maxHeight: .infinity)

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

    private func move(by offset: Int) {
        guard !scenarios.isEmpty,
              !isLocked,
              let currentScenarioID,
              let currentIndex = scenarios.firstIndex(where: { $0.id == currentScenarioID })
        else { return }

        let nextIndex = (currentIndex + offset + scenarios.count) % scenarios.count
        withAnimation {
            self.currentScenarioID = scenarios[nextIndex].id
        }
    }
}

private struct CarouselArrow: View {
    let systemName: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Color(.tertiaryLabel))
        .disabled(disabled)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous option" : "Next option")
    }
}

private struct AnswerActionButton: View {
    let hasSelection: Bool
    let isLocked: Bool
    let otherPersonIsReady: Bool
    let answerRole: AnswerRole
    let action: () -> Void

    private var title: String {
        if isLocked { return "Answer ready" }
        if otherPersonIsReady { return "Reveal answer" }
        return answerRole == .actual ? "Lock my answer" : "Lock my guess"
    }

    private var symbol: String {
        if isLocked { return "checkmark" }
        if otherPersonIsReady { return "eye" }
        return "lock"
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
        .tint(AppTheme.ink)
        .disabled(!hasSelection || isLocked)
        .opacity(!hasSelection && !isLocked ? 0.45 : 1)
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(
                color: Color.black.opacity(selected ? 0.16 : 0.10),
                radius: selected ? 13 : 10,
                x: 0,
                y: selected ? 6 : 4
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        selected ? AppTheme.accent : Color(.separator).opacity(0.2),
                        lineWidth: selected ? 3 : 1
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
