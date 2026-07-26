import SwiftUI

struct FeelingEntryView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focused: Bool

    private var frequentQuestions: [(label: String, question: String)] {
        appState.suggestedQuestions
    }

    private var title: String {
        switch appState.entryMode {
        case .concreteMoment:
            return "What happened?"
        case .connectionQuestion:
            return "Start with a question"
        }
    }

    private var guidance: String {
        switch appState.entryMode {
        case .concreteMoment:
            return "Tell us what happened, in your own words."
        case .connectionQuestion:
            return "We’ll turn it into a few everyday moments you can look at together."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(label: "Your starting point") {
                appState.stage = .entryChoice
            }
            .padding(.top, 8)

            Spacer(minLength: 30)

            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.ink)

            Text(guidance)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .padding(.top, 12)

            if appState.entryMode == .connectionQuestion {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Or start here")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)

                    FlowLayout(spacing: 8) {
                        ForEach(frequentQuestions.indices, id: \.self) { index in
                            let item = frequentQuestions[index]
                            QuestionShortcutChip(
                                title: item.label,
                                selected: appState.feeling == item.question
                            ) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    appState.feeling = item.question
                                }
                                focused = true
                            }
                        }
                    }
                }
                .padding(.top, 22)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                focused ? AppTheme.accent : Color(.separator),
                                lineWidth: focused ? 2 : 1
                            )
                    }

                TextEditor(text: $appState.feeling)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding()
                    .accessibilityLabel(title)

                if appState.entryMode == .connectionQuestion && appState.feeling.isEmpty {
                    Text(questionPlaceholder)
                        .font(.body)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 21)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: appState.entryMode == .connectionQuestion ? 180 : 220)
            .padding(.top, appState.entryMode == .connectionQuestion ? 18 : 24)

            Spacer()

            Button {
                Task {
                    await appState.prepareScenarioFlow()
                }
            } label: {
                HStack(spacing: 10) {
                    if appState.isGeneratingScenarios {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(appState.isGeneratingScenarios
                         ? "Writing everyday moments…"
                         : (appState.entryMode == .connectionQuestion
                            ? "Generate concrete examples"
                            : "Compare concrete versions"))
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .tint(AppTheme.ink)
            .frame(maxWidth: .infinity)
            .disabled(
                appState.feeling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                appState.isGeneratingScenarios
            )
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .alert(
            "Couldn’t generate scenarios",
            isPresented: Binding(
                get: { appState.generationError != nil },
                set: { if !$0 { appState.generationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                appState.generationError = nil
            }
        } message: {
            Text(appState.generationError ?? "")
        }
    }

    private var questionPlaceholder: String {
        if appState.reflectionOwner == .samar {
            return "For example: What would make the relationship feel less tiring to manage?"
        }
        return "For example: What does connection mean to me?"
    }
}

private struct QuestionShortcutChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? AppTheme.accent : AppTheme.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(selected ? AppTheme.accentSoft : Color(.secondarySystemBackground))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        selected ? AppTheme.accent.opacity(0.45) : Color(.separator),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "")
    }
}
