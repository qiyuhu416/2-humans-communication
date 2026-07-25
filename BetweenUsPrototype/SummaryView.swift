import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var appState: AppState
    let session: SavedSession?
    @State private var expandedAnswer: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button {
                        appState.stage = .qiyuHome
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to history")

                    Spacer()
                }

                Text("Your choices")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .tracking(-1)

                if let session {
                    Text(session.feeling)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryInk)

                    ForEach(session.answers) { record in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(record.opening)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryInk)
                                .lineSpacing(3)

                            summaryChoice(
                                key: "\(record.id)-qiyu",
                                label: firstLabel(for: record),
                                scenario: firstScenario(for: record)
                            )

                            summaryChoice(
                                key: "\(record.id)-samar",
                                label: secondLabel(for: record),
                                scenario: secondScenario(for: record)
                            )
                        }
                        .padding(.vertical, 14)
                    }

                    if let experiment = session.experiment {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TRY NEXT")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.secondaryInk)

                            Text(experiment)
                                .font(.body)
                                .foregroundStyle(Color.primary)
                        }
                        .padding()
                        .background(AppTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                Button("New reflection") {
                    appState.startNewReflection()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func firstLabel(for record: RoundAnswerRecord) -> String {
        record.focus == .qiyu ? "Qiyu" : "Samar"
    }

    private func secondLabel(for record: RoundAnswerRecord) -> String {
        record.focus == .qiyu ? "Samar’s guess" : "Qiyu’s guess"
    }

    private func firstScenario(for record: RoundAnswerRecord) -> Scenario {
        record.focus == .qiyu ? record.qiyuChoice : record.samarPrediction
    }

    private func secondScenario(for record: RoundAnswerRecord) -> Scenario {
        record.focus == .qiyu ? record.samarPrediction : record.qiyuChoice
    }

    private func summaryChoice(key: String, label: String, scenario: Scenario) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedAnswer = expandedAnswer == key ? nil : key
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .tracking(0.6)
                        Text(scenario.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    Image(systemName: expandedAnswer == key ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                if expandedAnswer == key {
                    Text(scenario.body)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineSpacing(3)
                        .padding(.top, 4)
                }
            }
            .padding(18)
            .background(.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CoDesignView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var experimentIsFocused: Bool

    private let proposedExperiment = """
    By Tuesday, suggest one possible time for the weekend. It can stay tentative until Thursday. If that time changes, suggest one other time.
    """

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Try one small thing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.ink)

                Text("This combines the early signal Qiyu compared with the flexibility Samar compared.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Label("One-week experiment", systemImage: "calendar.badge.clock")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    TextEditor(text: $appState.sharedExperiment)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .scrollContentBackground(.hidden)
                        .focused($experimentIsFocused)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    experimentIsFocused ? AppTheme.accent : Color(.separator),
                                    lineWidth: experimentIsFocused ? 2 : 1
                                )
                        }
                }
                .padding()
                .background(AppTheme.accentSoft.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text("Edit any detail until both people could realistically try it.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)

                Button {
                    appState.finishSession()
                } label: {
                    Label("Save this conversation", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .tint(AppTheme.ink)
                .disabled(appState.sharedExperiment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Save without an experiment") {
                    appState.sharedExperiment = ""
                    appState.finishSession()
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if appState.sharedExperiment.isEmpty {
                appState.sharedExperiment = proposedExperiment
            }
        }
    }
}

struct QiyuHomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Open a past conversation to see both people’s choices.")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .listRowBackground(AppTheme.accentSoft.opacity(0.35))
                        .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
                }

                Section {
                    ForEach(appState.savedSessions) { session in
                        Button {
                            appState.openSession(session)
                        } label: {
                            SessionHistoryRow(session: session)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 16))
                        .listRowBackground(Color(.systemBackground))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.stage = .perspective
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.startNewReflection()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New reflection")
                }
            }
        }
    }
}

private struct SessionHistoryRow: View {
    let session: SavedSession

    var body: some View {
        HStack(spacing: 14) {
            SessionThumbnail()

            VStack(alignment: .leading, spacing: 4) {
                Text(session.feeling)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                Label(
                    "\(session.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(session.answers.count) questions",
                    systemImage: "person.2"
                )
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this saved conversation")
    }
}

private struct SessionThumbnail: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 1, green: 0.72, blue: 0.08)

                Ellipse()
                    .fill(AppTheme.accent)
                    .frame(width: proxy.size.width * 1.45, height: proxy.size.height * 0.68)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.92)

                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.ink.opacity(0.8))
                    .offset(y: 7)
            }
        }
        .frame(width: 74, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
    }
}
