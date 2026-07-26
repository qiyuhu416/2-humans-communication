import SwiftUI

struct EntryChoiceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(label: "Start") {
                appState.stage = .perspective
            }
            .padding(.top, 8)

            Spacer()

            Text("Where should we begin?")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.ink)

            VStack(spacing: 14) {
                entryCard(
                    title: "Start with a moment",
                    detail: "Describe one recent thing that happened.",
                    systemImage: "text.quote",
                    mode: .concreteMoment
                )

                entryCard(
                    title: "Start with a question",
                    detail: "Type the question you want to explore.",
                    systemImage: "questionmark.bubble",
                    mode: .connectionQuestion
                )
            }
            .padding(.top, 34)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func entryCard(
        title: String,
        detail: String,
        systemImage: String,
        mode: ReflectionEntryMode
    ) -> some View {
        Button {
            appState.entryMode = mode
            appState.feeling = ""
            appState.stage = .qiyuFeeling
        } label: {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.07), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}
