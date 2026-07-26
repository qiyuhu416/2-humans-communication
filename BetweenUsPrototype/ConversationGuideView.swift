import SwiftUI

struct ConversationGuideView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.bottom, 26)

            Text("Begin honestly")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.ink)

            Text(introText)
                .font(.title3)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineSpacing(5)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 22) {
                guideRow(
                    symbol: "hand.tap",
                    text: "\(appState.selectedPersonName), choose what you’d feel good receiving."
                )

                guideRow(
                    symbol: "heart",
                    text: "\(appState.otherParticipantName), choose what you could comfortably do on a real week."
                )
            }
            .padding(.top, 34)

            Text("The point isn’t to match. It’s to see where you already meet—and where you may need to talk.")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .padding(.top, 30)

            if appState.scenarioSourceMode == .adaptive,
               let notice = appState.generationNotice {
                Label(
                    notice,
                    systemImage: appState.isOnDeviceAIAvailable
                        ? "iphone.gen3.radiowaves.left.and.right"
                        : "wand.and.stars"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
                .padding(.top, 18)
            }

            Spacer()

            HStack {
                Button {
                    appState.stage = .qiyuHome
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer()

                Button {
                    appState.stage = .roundIntro
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Begin")
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 28)
        .background(AppTheme.page)
        .accessibilityElement(children: .contain)
    }

    private var introText: String {
        if appState.scenarioSourceMode == .adaptive {
            return "We used your words to choose the first few moments. What comes next will adjust as you answer. There are no right answers here."
        }
        return "Sometimes it’s easier to talk about a real moment than a big idea. There are no right answers here."
    }

    private func guideRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
