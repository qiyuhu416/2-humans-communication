import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPerson: Perspective = .qiyu

    private var selectedProfile: PersonProfile? {
        appState.profiles.first(where: { $0.id == selectedPerson })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("These notes help AI create concrete comparisons. Nothing here is a diagnosis or a permanent conclusion.")
                        .font(.body)
                        .foregroundStyle(Color.secondary)

                    Picker("Person", selection: $selectedPerson) {
                        Text("Qiyu").tag(Perspective.qiyu)
                        Text("Samar").tag(Perspective.samar)
                    }
                    .pickerStyle(.segmented)

                    if let profile = selectedProfile {
                        SuggestedCommunicationCard(
                            person: profile.name,
                            suggestion: communicationSuggestion(for: profile.id)
                        )

                        ForEach(ProfileInsightKind.allCasesCompat, id: \.self) { kind in
                            let insights = profile.insights.filter { $0.kind == kind }
                            if !insights.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(kind.label)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)

                                    ForEach(insights) { insight in
                                        ProfileInsightCard(
                                            insight: insight,
                                            person: profile
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(AppTheme.page)
            .navigationTitle("What AI knows")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.closeProfiles()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
    }

    private func communicationSuggestion(for person: Perspective) -> String {
        switch person {
        case .qiyu:
            return "When the week is busy, name a possible shared time and when it can be confirmed. For example: “Saturday afternoon might work. I’ll confirm by Thursday.”"
        case .samar:
            return "Start with one concrete moment and one repeatable action. For example: “When should we decide whether Saturday works?”"
        }
    }
}

private struct SuggestedCommunicationCard: View {
    let person: String
    let suggestion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suggested communication", systemImage: "text.bubble")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(suggestion)
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineSpacing(3)

            Text("A starting point for \(person) to confirm, edit, or reject.")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileInsightCard: View {
    @EnvironmentObject private var appState: AppState
    let insight: ProfileInsight
    let person: PersonProfile
    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing {
                TextEditor(text: $draft)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            } else {
                Text(insight.statement)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineSpacing(3)
            }

            Text(insight.evidence)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .lineSpacing(2)

            HStack {
                Label(insight.source.label, systemImage: sourceIcon)
                    .font(.caption)
                    .foregroundStyle(sourceColor)

                Spacer()

                if insight.source != .selfConfirmed {
                    Button("Confirm") {
                        update(statement: insight.statement, source: .selfConfirmed)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                }

                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        update(statement: draft, source: insight.source)
                    } else {
                        draft = insight.statement
                    }
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
    }

    private var sourceIcon: String {
        switch insight.source {
        case .selfConfirmed: return "checkmark.seal.fill"
        case .partnerObserved: return "eye"
        case .aiHypothesis: return "sparkles"
        }
    }

    private var sourceColor: Color {
        insight.source == .selfConfirmed ? AppTheme.accent : Color.secondary
    }

    private func update(statement: String, source: ProfileEvidenceSource) {
        var updatedProfile = person
        guard let index = updatedProfile.insights.firstIndex(where: { $0.id == insight.id }) else { return }
        updatedProfile.insights[index].statement = statement
        updatedProfile.insights[index].source = source
        appState.updateProfile(updatedProfile)
    }
}

private extension ProfileInsightKind {
    static let allCasesCompat: [ProfileInsightKind] = [
        .connection,
        .constraint,
        .communication,
        .sustainableAction
    ]
}
