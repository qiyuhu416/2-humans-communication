import SwiftUI

struct RoundIntroView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var horizontalOffset: CGFloat = 0
    @State private var horizonExpanded = false
    @State private var isTransitioning = false
    @State private var showRationale = false
    @State private var rationalePull: CGFloat = 0
    private let rationaleThreshold: CGFloat = 100

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                AppTheme.page.ignoresSafeArea()

                storyContent

                if !showRationale {
                    rationaleArc(in: proxy.size)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if horizonExpanded {
                    WarmHorizon(expanded: true)
                        .transition(.opacity)
                }
            }
        }
        .offset(x: horizontalOffset)
        .contentShape(Rectangle())
        .gesture(forwardGesture)
        .sheet(isPresented: $showRationale) {
            AIRationaleView(
                round: appState.currentRound,
                sourceQuestion: appState.feeling
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemBackground))
        }
        .animation(.easeInOut(duration: 0.22), value: showRationale)
    }

    private var storyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 70)

            WeekTimeline(
                currentDayIndex: appState.currentRound.currentDayIndex,
                targetDayIndex: appState.currentRound.targetDayIndex,
                targetLabel: appState.currentRound.timelineTargetLabel
            )

            Text(appState.currentRound.opening)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.ink)
                .minimumScaleFactor(0.82)
                .padding(.top, 34)

            Spacer()

            Button(action: advanceToQuestions) {
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isTransitioning || showRationale)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, 126)
            .accessibilityLabel("Continue")
        }
        .padding(.horizontal, 28)
    }

    private func rationaleArc(in size: CGSize) -> some View {
        let visibleHeight = AppTheme.swipeArcVisibleHeight(for: size.height)
        let restingOffset = max(240, size.height - visibleHeight)
        let currentOffset = max(0, restingOffset - rationalePull)

        return ZStack(alignment: .top) {
            CurvedTopArc(depth: AppTheme.swipeArcRestingDepth)
                .fill(AppTheme.accent)
                .ignoresSafeArea(edges: .bottom)

            rationaleHandle(height: visibleHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    showRationale = true
                }
                .gesture(rationaleGesture)
        }
        .frame(width: size.width, height: size.height)
        .offset(y: currentOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.88), value: rationalePull)
    }

    private func rationaleHandle(height: CGFloat) -> some View {
        SwipeUpHandle(
            pullDistance: rationalePull,
            threshold: rationaleThreshold,
            destination: "a closer look",
            height: height
        )
    }

    private var rationaleGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                rationalePull = max(0, -value.translation.height)
            }
            .onEnded { value in
                let projected = max(rationalePull, -value.predictedEndTranslation.height)
                withAnimation {
                    rationalePull = 0
                    if projected >= rationaleThreshold {
                        showRationale = true
                    }
                }
            }
    }

    private var forwardGesture: some Gesture {
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

private struct WeekTimeline: View {
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    let currentDayIndex: Int
    let targetDayIndex: Int
    let targetLabel: String

    private var showsTarget: Bool {
        targetDayIndex != currentDayIndex
            && !targetLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedDayIndices: [Int] {
        if showsTarget && targetDayIndex < currentDayIndex {
            return (0..<7).map { (currentDayIndex + $0) % days.count }
        }
        return Array(days.indices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(displayedDayIndices.enumerated()), id: \.offset) { slot, dayIndex in
                    let day = days[dayIndex]

                    VStack(spacing: 6) {
                        Text(roleLabel(for: dayIndex) ?? " ")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .opacity(roleLabel(for: dayIndex) == nil ? 0 : 1)

                        ZStack {
                            if slot < displayedDayIndices.count - 1 {
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity)
                                    .offset(x: 18)
                            }

                            Circle()
                                .fill(
                                    dayIndex == currentDayIndex
                                        ? AppTheme.accent
                                        : showsTarget && dayIndex == targetDayIndex
                                            ? AppTheme.accentSoft
                                            : Color(.systemBackground)
                                )
                                .frame(
                                    width: dayIndex == currentDayIndex || (showsTarget && dayIndex == targetDayIndex) ? 14 : 10,
                                    height: dayIndex == currentDayIndex || (showsTarget && dayIndex == targetDayIndex) ? 14 : 10
                                )
                                .overlay {
                                    Circle()
                                        .stroke(
                                            dayIndex == currentDayIndex || (showsTarget && dayIndex == targetDayIndex)
                                                ? AppTheme.accent
                                                : Color(.tertiaryLabel),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .frame(height: 16)

                        Text(day)
                            .font(.caption2)
                            .fontWeight(
                                dayIndex == currentDayIndex || (showsTarget && dayIndex == targetDayIndex)
                                    ? .semibold
                                    : .regular
                            )
                            .foregroundStyle(
                                dayIndex == currentDayIndex || (showsTarget && dayIndex == targetDayIndex)
                                    ? AppTheme.ink
                                    : Color(.secondaryLabel)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            showsTarget
                ? "Week timeline. Today is \(days[safe: currentDayIndex] ?? "today"). The proposed time is \(days[safe: targetDayIndex] ?? "later")."
                : "Week timeline. Today is \(days[safe: currentDayIndex] ?? "today"). No time has been proposed."
        )
    }

    private func roleLabel(for dayIndex: Int) -> String? {
        if dayIndex == currentDayIndex {
            return "Today"
        }
        if showsTarget && dayIndex == targetDayIndex {
            return "Proposed time"
        }
        return nil
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct TaskRow: View {
    let name: String
    let task: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 48, alignment: .leading)

            Text(task)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AIRationaleView: View {
    let round: ScenarioRound
    let sourceQuestion: String

    var body: some View {
        ScrollView {
            AIRationaleContent(
                round: round,
                sourceQuestion: sourceQuestion
            )
            .padding(24)
        }
    }
}

struct AIRationaleContent: View {
    let round: ScenarioRound
    let sourceQuestion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("A closer look")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.ink)

            if !sourceQuestion.isEmpty {
                rationaleSection(
                    title: "What you brought in",
                    body: sourceQuestion,
                    systemImage: "text.quote"
                )
            }

            variableMap

            constantsCard

            visualRationaleCard

            readingSection

            Text("This is simply a way into the conversation—not a verdict on either of you or how much you care.")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
                .padding(.top, 4)
        }
    }

    private var variableMap: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("What may shape this moment", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            FlowLayout(spacing: 9) {
                ForEach(round.potentialVariables, id: \.self) { variable in
                    let isTested = variable == round.testedVariableLabel

                    HStack(spacing: 6) {
                        if isTested {
                            Image(systemName: "scope")
                                .font(.caption.weight(.bold))
                        }

                        Text(variable)
                            .font(.subheadline.weight(isTested ? .semibold : .medium))
                    }
                    .foregroundStyle(isTested ? Color.white : AppTheme.secondaryInk)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(isTested ? AppTheme.accent : Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                    .overlay {
                        if isTested {
                            Capsule()
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        }
                    }
                    .accessibilityLabel(
                        isTested ? "\(variable), variable being tested" : variable
                    )
                }
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scope")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Testing variable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(round.testedVariableLabel)
                        .font(.headline)
                        .foregroundStyle(Color.primary)

                    Text(round.testVariable)
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(16)
            .background(AppTheme.accentSoft.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var constantsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("What stays the same", systemImage: "equal.circle")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            FlowLayout(spacing: 8) {
                ForEach(round.heldConstant, id: \.self) { item in
                    Label(item, systemImage: "lock.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color(.separator), lineWidth: 1)
                        }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var visualRationaleCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 42, height: 42)

                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Why this moment came up")
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(round.rationale)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested reading", systemImage: "books.vertical")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            ForEach(round.suggestedReadings) { reading in
                if let url = URL(string: reading.url) {
                    Link(destination: url) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "doc.text")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(reading.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                                    .multilineTextAlignment(.leading)

                                Text(reading.source)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)

                                Text(reading.takeaway)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryInk)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(2)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private func rationaleSection(
        title: String,
        body: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(body)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
