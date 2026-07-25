import SwiftUI

struct PerspectiveEntryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 54)

            Text("Start here")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .tracking(-1.2)

            VStack(spacing: 14) {
                PerspectiveCard(
                    name: "Qiyu",
                    detail: "I want to explore something I feel.",
                    badge: "Ready"
                ) {
                    appState.startQiyuFlow()
                }

                PerspectiveCard(
                    name: "Samar",
                    detail: "I want to explore something I feel.",
                    badge: nil
                ) {
                    appState.startSamarFlow()
                }
            }
            .padding(.top, 38)

            Spacer()

        }
        .padding(.horizontal, 24)
        .background(WarmHorizon())
    }
}
