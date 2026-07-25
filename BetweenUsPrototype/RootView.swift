import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            setBackground.ignoresSafeArea()

            switch appState.stage {
            case .perspective:
                PerspectiveEntryView()
            case .qiyuHome:
                QiyuHomeView()
            case .entryChoice:
                EntryChoiceView()
            case .qiyuFeeling:
                FeelingEntryView()
            case .roundIntro:
                RoundIntroView()
            case .qiyuScenario:
                ScenarioSplitView()
            case .reveal:
                RevealView()
            case .coDesign:
                CoDesignView()
            case .summary:
                SummaryView(session: appState.selectedSession)
            case .samarPlaceholder:
                SamarPlaceholderView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: String(describing: appState.stage))
    }

    private var setBackground: Color {
        switch appState.stage {
        case .qiyuScenario, .reveal:
            return AppTheme.accent
        default:
            return AppTheme.page
        }
    }
}
