import SwiftUI

struct RoundIntroView: View {
    @EnvironmentObject private var appState: AppState
    @State private var horizontalOffset: CGFloat = 0
    @State private var horizonExpanded = false
    @State private var isTransitioning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text(appState.currentRound.opening)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .tracking(-0.7)
                .lineSpacing(7)

            Spacer()

            HStack {
                Spacer()
                Button(action: advanceToQuestions) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 52, height: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isTransitioning)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
        .background(WarmHorizon(expanded: horizonExpanded))
        .offset(x: horizontalOffset)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onChanged { value in
                    guard value.translation.width > 0,
                          abs(value.translation.width) > abs(value.translation.height)
                    else { return }
                    horizontalOffset = min(value.translation.width * 0.22, 40)
                }
                .onEnded { value in
                    let moveForward = value.translation.width > 70
                        && abs(value.translation.width) > abs(value.translation.height)

                    if moveForward {
                        advanceToQuestions()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            horizontalOffset = 0
                        }
                    }
                }
        )
    }

    private func advanceToQuestions() {
        guard !isTransitioning else { return }
        isTransitioning = true

        withAnimation(.easeInOut(duration: 0.58)) {
            horizonExpanded = true
            horizontalOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
            appState.stage = .qiyuScenario
        }
    }
}
