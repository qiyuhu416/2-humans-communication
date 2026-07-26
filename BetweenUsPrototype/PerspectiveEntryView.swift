import SwiftUI

struct PerspectiveEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var flowers: [HomeFlower] = []

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let waterline = proxy.size.height * 0.90

                ZStack {
                    WarmHorizon()

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    plantFlower(at: value.location, waterline: waterline)
                                }
                        )
                        .accessibilityHidden(true)

                    ForEach(flowers) { flower in
                        GrowingHomeFlower(
                            stemHeight: flower.stemHeight,
                            color: flower.color
                        ) {
                            flowers.removeAll { $0.id == flower.id }
                        }
                        .frame(width: 58, height: flower.stemHeight + 42)
                        .position(
                            x: flower.x,
                            y: waterline - flower.stemHeight / 2 - 9
                        )
                        .allowsHitTesting(false)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 54)

                        Text("Start here")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .tracking(-1.2)

                        VStack(spacing: 14) {
                            PerspectiveCard(
                                name: "Qiyu",
                                detail: "I want to make a hard-to-name feeling more concrete.",
                                badge: "Ready"
                            ) {
                                appState.startQiyuFlow()
                            }

                            PerspectiveCard(
                                name: "Samar",
                                detail: "I want to test what would help—and what feels realistic.",
                                badge: nil
                            ) {
                                appState.startSamarFlow()
                            }
                        }
                        .padding(.top, 38)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.openProfiles(returningTo: .perspective)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Profile")
                    .accessibilityHint("Shows what the app knows about each person")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func plantFlower(at point: CGPoint, waterline: CGFloat) {
        // Let the stem grow all the way from the waterline to the tap. There is
        // intentionally no maximum height or horizontal planting boundary.
        let height = max(waterline - point.y, 0)
        let colors: [Color] = [
            Color(red: 0.97, green: 0.34, blue: 0.30),
            Color(red: 0.55, green: 0.36, blue: 0.85),
            Color(red: 0.98, green: 0.66, blue: 0.20),
            Color(red: 0.93, green: 0.40, blue: 0.62)
        ]

        withAnimation(.easeInOut(duration: 0.2)) {
            flowers.append(
                HomeFlower(
                    x: point.x,
                    stemHeight: height,
                    color: colors[flowers.count % colors.count]
                )
            )
            if flowers.count > 14 {
                flowers.removeFirst()
            }
        }
    }
}

private struct HomeFlower: Identifiable {
    let id = UUID()
    let x: CGFloat
    let stemHeight: CGFloat
    let color: Color
}

private struct GrowingHomeFlower: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stemHeight: CGFloat
    let color: Color
    let onFinished: () -> Void
    @State private var growth: CGFloat = 0
    @State private var bloomScale: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color(red: 0.25, green: 0.55, blue: 0.30))
                .frame(width: 4, height: stemHeight * growth)

            Capsule()
                .fill(Color(red: 0.31, green: 0.63, blue: 0.34))
                .frame(width: 18, height: 9)
                .rotationEffect(.degrees(-28))
                .offset(x: -8, y: -stemHeight * growth * 0.46)
                .opacity(growth)

            flowerHead
                .scaleEffect(bloomScale)
                .offset(y: -stemHeight * growth + 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            if reduceMotion {
                growth = 1
                bloomScale = 1
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                    growth = 1
                }
                withAnimation(.spring(response: 0.52, dampingFraction: 0.58).delay(0.42)) {
                    bloomScale = 1
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }

            if reduceMotion {
                onFinished()
            } else {
                withAnimation(.easeInOut(duration: 0.55)) {
                    growth = 0
                    bloomScale = 0
                }

                try? await Task.sleep(nanoseconds: 550_000_000)
                guard !Task.isCancelled else { return }
                onFinished()
            }
        }
        .accessibilityHidden(true)
    }

    private var flowerHead: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 12, height: 25)
                    .offset(y: -12)
                    .rotationEffect(.degrees(Double(index) * 60))
            }

            Circle()
                .fill(Color(red: 1.0, green: 0.78, blue: 0.18))
                .frame(width: 14, height: 14)
        }
        .frame(width: 48, height: 48)
    }
}
