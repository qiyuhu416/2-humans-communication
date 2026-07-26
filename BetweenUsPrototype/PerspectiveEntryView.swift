import SwiftUI

struct FlowerPlantRequest: Equatable {
    let id = UUID()
    let point: CGPoint

    static func == (lhs: FlowerPlantRequest, rhs: FlowerPlantRequest) -> Bool {
        lhs.id == rhs.id
    }
}

struct FlowerGardenBackground: View {
    @Binding var plantRequest: FlowerPlantRequest?
    var surfaceY: CGFloat?
    @State private var flowers: [HomeFlower] = []

    var body: some View {
        GeometryReader { proxy in
            let flowerBaseline = proxy.size.height * 0.50
            let surfaceRatio = min(max((surfaceY ?? proxy.size.height * 0.61) / proxy.size.height, 0), 1)

            ZStack {
                WarmHorizon(surfaceRatio: surfaceRatio)

                ForEach(flowers) { flower in
                    GrowingHomeFlower(
                        stemHeight: flower.stemHeight,
                        color: flower.color,
                        bloomDurationNanoseconds: 3_000_000_000
                    ) {
                        flowers.removeAll { $0.id == flower.id }
                    }
                    .frame(width: 58, height: flower.stemHeight + 42)
                    .position(
                        x: flower.x,
                        y: flowerBaseline - flower.stemHeight / 2 - 9
                    )
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: plantRequest) { _, request in
                guard let request else { return }
                plantFlower(at: request.point, waterline: flowerBaseline)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func plantFlower(at point: CGPoint, waterline: CGFloat) {
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

struct PerspectiveEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var flowers: [HomeFlower] = []

    var body: some View {
        GeometryReader { proxy in
            let waterline = proxy.size.height * 0.90

            ZStack {
                WarmHorizon()

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

                VStack(alignment: .leading, spacing: 12) {
                    Spacer()

                    Text("Making it concrete")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .tracking(-1)

                    Text("Finding two everyday versions you can talk about together.")
                        .font(.title3)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineSpacing(4)

                    Spacer()
                        .frame(height: proxy.size.height * 0.34)
                }
                .padding(.horizontal, 28)

                Button {
                    appState.stage = .qiyuHome
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 52)
                .padding(.leading, 18)
                .accessibilityLabel("Back")
            }
            .task {
                await animateFlowers(in: proxy.size, waterline: waterline)
            }
        }
        .ignoresSafeArea()
    }

    @MainActor
    private func animateFlowers(in size: CGSize, waterline: CGFloat) async {
        let points = [
            CGPoint(x: size.width * 0.25, y: size.height * 0.69),
            CGPoint(x: size.width * 0.50, y: size.height * 0.61),
            CGPoint(x: size.width * 0.76, y: size.height * 0.72)
        ]

        let generationTask = Task {
            await appState.prepareScenarioFlow(advanceWhenReady: false)
        }

        for point in points {
            plantFlower(at: point, waterline: waterline)
            try? await Task.sleep(nanoseconds: 280_000_000)
        }

        try? await Task.sleep(nanoseconds: 650_000_000)
        await generationTask.value

        guard !Task.isCancelled else { return }
        appState.stage = appState.generationError == nil ? .conversationGuide : .qiyuHome
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
    var fadesAfterBloom = true
    var bloomDurationNanoseconds: UInt64 = 2_000_000_000
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
            guard fadesAfterBloom else { return }
            try? await Task.sleep(nanoseconds: bloomDurationNanoseconds)
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
