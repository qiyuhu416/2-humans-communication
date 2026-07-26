import SwiftUI
import CoreMotion

enum AppTheme {
    static let page = Color(red: 0.985, green: 0.978, blue: 0.97)
    static let ink = Color(red: 0.20, green: 0.19, blue: 0.19)
    static let secondaryInk = Color(red: 0.43, green: 0.41, blue: 0.40)
    static let card = Color.white
    static let accent = Color(red: 1.0, green: 0.49, blue: 0.20)
    static let accentSoft = Color(red: 1.0, green: 0.92, blue: 0.86)
    static let questionBackground = Color(.systemGroupedBackground)
    static let divider = Color.black.opacity(0.08)
    static let swipeArcRestingHeight: CGFloat = 112
    static let swipeArcRestingDepth: CGFloat = 42
    static let swipeArcOpenDepth: CGFloat = 32

    static func swipeArcVisibleHeight(for screenHeight: CGFloat) -> CGFloat {
        // Rest the shared affordance 5% of the screen lower than its original
        // position while preserving enough room for a readable system label.
        max(64, swipeArcRestingHeight - screenHeight * 0.05)
    }
}

struct WarmHorizon: View {
    var expanded = false

    var body: some View {
        Group {
            if expanded {
                GeometryReader { proxy in
                    Ellipse()
                        .fill(AppTheme.accent)
                        .frame(width: proxy.size.width * 3.2, height: proxy.size.height * 3.2)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .ignoresSafeArea()
                }
            } else {
                FluidWarmHorizon()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FluidWarmHorizon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = LiquidMotionObserver()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let phase = reduceMotion
                    ? 0
                    : timeline.date.timeIntervalSinceReferenceDate * 0.85
                // Device tilt remains responsive even when Reduce Motion is on;
                // only the decorative continuous wave is paused.
                let tilt = motion.horizontalTilt
                let verticalShift = motion.verticalTilt * 42
                let splash = reduceMotion ? 0 : motion.splashEnergy

                ZStack {
                    LiquidSurface(
                        phase: phase + 0.8,
                        tilt: tilt * 170,
                        amplitude: reduceMotion ? 0 : 7 + splash * 18,
                        surfaceY: proxy.size.height * 0.885 + verticalShift
                    )
                    .fill(AppTheme.accentSoft.opacity(0.75))

                    LiquidSurface(
                        phase: phase + Double(splash) * 2.4,
                        tilt: tilt * 210,
                        amplitude: reduceMotion ? 0 : 10 + splash * 28,
                        surfaceY: proxy.size.height * 0.90 + verticalShift
                    )
                    .fill(AppTheme.accent)

                    if splash > 0.08 {
                        LiquidSplashLayer(
                            time: timeline.date.timeIntervalSinceReferenceDate,
                            energy: splash,
                            surfaceY: proxy.size.height * 0.90 + verticalShift,
                            tilt: tilt * 210
                        )
                        .fill(AppTheme.accent)
                        .transition(.opacity)
                    }
                }
                .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.82), value: motion.horizontalTilt)
                .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.82), value: motion.verticalTilt)
                .ignoresSafeArea()
            }
        }
        .onAppear {
            motion.start()
        }
        .onDisappear {
            motion.stop()
        }
        .accessibilityHidden(true)
    }
}

private struct LiquidSurface: Shape {
    var phase: Double
    var tilt: CGFloat
    var amplitude: CGFloat
    var surfaceY: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<Double, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(phase, tilt),
                AnimatablePair(amplitude, surfaceY)
            )
        }
        set {
            phase = newValue.first.first
            tilt = newValue.first.second
            amplitude = newValue.second.first
            surfaceY = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: waveY(x: rect.minX, in: rect)))

        let step = max(3, rect.width / 90)
        var x = rect.minX
        while x <= rect.maxX {
            path.addLine(to: CGPoint(x: x, y: waveY(x: x, in: rect)))
            x += step
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private func waveY(x: CGFloat, in rect: CGRect) -> CGFloat {
        let progress = (x - rect.midX) / max(rect.width, 1)
        let primaryWave = sin((progress * .pi * 2.1) + phase) * amplitude
        let smallerWave = sin((progress * .pi * 5.2) - phase * 1.7) * amplitude * 0.22
        return surfaceY + primaryWave + smallerWave + progress * tilt
    }
}

private struct LiquidSplashLayer: Shape {
    let time: Double
    let energy: CGFloat
    let surfaceY: CGFloat
    let tilt: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        for index in 0..<10 {
            let seed = Double(index) * 0.173
            let age = (time * (0.72 + seed * 0.2) + seed)
                .truncatingRemainder(dividingBy: 1)
            let normalizedX = (seed * 4.7 + time * 0.035)
                .truncatingRemainder(dividingBy: 1)
            let x = rect.width * CGFloat(normalizedX)
            let progress = (x - rect.midX) / max(rect.width, 1)
            let localSurface = surfaceY + progress * tilt
            let arc = sin(age * .pi)
            let rise = CGFloat(arc) * (28 + energy * 110)
            let sideways = CGFloat(cos(age * .pi)) * energy * CGFloat(index - 5) * 2.2
            let size = 3 + energy * CGFloat(4 + index % 4)
            let y = localSurface - rise

            path.addEllipse(
                in: CGRect(
                    x: x + sideways - size / 2,
                    y: y - size / 2,
                    width: size,
                    height: size * 1.25
                )
            )
        }

        return path
    }
}

@MainActor
private final class LiquidMotionObserver: ObservableObject {
    @Published var horizontalTilt: CGFloat = 0
    @Published var verticalTilt: CGFloat = 0
    @Published var splashEnergy: CGFloat = 0

    private let manager = CMMotionManager()
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        if manager.isAccelerometerAvailable {
            manager.accelerometerUpdateInterval = 1 / 30
            manager.startAccelerometerUpdates(to: .main) { [weak self] sample, _ in
                guard let self, let acceleration = sample?.acceleration else { return }
                update(
                    horizontal: acceleration.x,
                    vertical: acceleration.y + 0.82,
                    shakeMagnitude: abs(
                        sqrt(
                            acceleration.x * acceleration.x +
                            acceleration.y * acceleration.y +
                            acceleration.z * acceleration.z
                        ) - 1
                    )
                )
            }
        } else if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1 / 30
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let motion else { return }
                let gravity = motion.gravity
                update(
                    horizontal: gravity.x,
                    vertical: gravity.y + 0.82,
                    shakeMagnitude: sqrt(
                        motion.userAcceleration.x * motion.userAcceleration.x +
                        motion.userAcceleration.y * motion.userAcceleration.y +
                        motion.userAcceleration.z * motion.userAcceleration.z
                    )
                )
            }
        } else {
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        manager.stopAccelerometerUpdates()
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }

    private func update(horizontal: Double, vertical: Double, shakeMagnitude: Double) {
        let clampedHorizontal = CGFloat(max(-1, min(1, horizontal)))
        let clampedVertical = CGFloat(max(-1, min(1, vertical)))
        let detectedSplash = CGFloat(max(0, min(1, (shakeMagnitude - 0.06) * 2.8)))

        // A small low-pass filter removes hand jitter while preserving rotation.
        horizontalTilt = horizontalTilt * 0.78 + clampedHorizontal * 0.22
        verticalTilt = verticalTilt * 0.78 + clampedVertical * 0.22
        splashEnergy = max(detectedSplash, splashEnergy * 0.90)
    }

    deinit {
        manager.stopAccelerometerUpdates()
        manager.stopDeviceMotionUpdates()
    }
}

struct LayeredWarmBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 1.0, green: 0.72, blue: 0.08)

                Ellipse()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.12))
                    .frame(width: proxy.size.width * 1.7, height: proxy.size.height * 0.48)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.36)

                Ellipse()
                    .fill(Color(red: 1.0, green: 0.90, blue: 0.47))
                    .frame(width: proxy.size.width * 1.75, height: proxy.size.height * 0.62)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.66)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

struct CurvedTopArc: Shape {
    var depth: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + depth),
            control: CGPoint(x: rect.midX, y: rect.minY - depth)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SwipeUpHandle: View {
    let pullDistance: CGFloat
    let threshold: CGFloat
    let destination: String
    let height: CGFloat

    private var message: String {
        if pullDistance >= threshold {
            return "Let go"
        }
        if pullDistance > 10 {
            return "Keep going"
        }
        return "Pull up to talk more"
    }

    var body: some View {
        Text(message)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(AppTheme.ink)
            .contentTransition(.numericText())
            .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .animation(.easeOut(duration: 0.16), value: message)
        .accessibilityElement()
        .accessibilityLabel("Swipe up for \(destination)")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(enabled ? AppTheme.ink : AppTheme.ink.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
