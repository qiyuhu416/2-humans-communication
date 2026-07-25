import SwiftUI

struct SamarPlaceholderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(label: "Samar") {
                appState.stage = .perspective
            }
            .padding(.top, 8)

            Spacer()

            Image(systemName: "person.2.wave.2")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(AppTheme.accent)

            Text("Samar’s reflection\nstarts here.")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .tracking(-0.9)
                .padding(.top, 22)

            Text("This entry point is intentionally a placeholder for the first prototype. It will later use Samar’s own abstract feeling, hypotheses, and adaptive scenarios.")
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.secondaryInk)
                .lineSpacing(4)
                .padding(.top, 16)

            Spacer()

            Button("Back to both perspectives") {
                appState.stage = .perspective
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
    }
}
