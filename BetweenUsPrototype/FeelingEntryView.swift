import SwiftUI

struct FeelingEntryView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focused: Bool

    private var title: String {
        switch appState.entryMode {
        case .concreteMoment:
            return "What happened?"
        case .connectionQuestion:
            return "What does connection mean to you?"
        }
    }

    private var guidance: String {
        switch appState.entryMode {
        case .concreteMoment:
            return "What happened? What did you expect? What happened instead?"
        case .connectionQuestion:
            return "You can describe one moment when you felt connected, or one moment when you did not."
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
            }
            .frame(height: 220)
            .padding(.top, 24)

            Spacer()

            Button("Compare concrete versions") {
                appState.currentRoundIndex = 0
                appState.stage = .roundIntro
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .tint(AppTheme.ink)
            .frame(maxWidth: .infinity)
            .disabled(appState.feeling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
    }
}
