import SwiftUI
import AppKit

// MARK: - Animatable Wedge

struct WedgeShape: Shape {
    var midAngle: Double
    var sliceAngle: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat

    var animatableData: Double {
        get { midAngle }
        set { midAngle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: c, radius: outerRadius,
                 startAngle: .degrees(midAngle - sliceAngle / 2),
                 endAngle: .degrees(midAngle + sliceAngle / 2),
                 clockwise: false)
        p.addArc(center: c, radius: innerRadius,
                 startAngle: .degrees(midAngle + sliceAngle / 2),
                 endAngle: .degrees(midAngle - sliceAngle / 2),
                 clockwise: true)
        p.closeSubpath()
        return p
    }
}

// MARK: - PieMenuView

struct PieMenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    var onAppSelected: ((AppItem) -> Void)?
    var onSettingsTapped: (() -> Void)?

    static let windowSize: CGFloat = 480

    @State private var wedgeAngle: Double = 90
    @State private var showWedge: Bool = false

    init(appState: AppState,
         onAppSelected: ((AppItem) -> Void)? = nil,
         onSettingsTapped: (() -> Void)? = nil) {
        self.appState = appState
        self.onAppSelected = onAppSelected
        self.onSettingsTapped = onSettingsTapped
    }

    private var iconOrbitRadius: CGFloat { appState.settings.menuRadius }
    private var ringThickness: CGFloat { 100 }
    private var outerRadius: CGFloat { iconOrbitRadius + ringThickness / 2 }
    private var innerRadius: CGFloat { iconOrbitRadius - ringThickness / 2 }
    private var center: CGFloat { Self.windowSize / 2 }
    private var iconSize: CGFloat { appState.settings.iconSize }

    // 深色：带微蓝色调的暗色，模拟 macOS 毛玻璃质感
    private var ringFill: Color {
        colorScheme == .dark ? Color(red: 0.16, green: 0.17, blue: 0.21) : .white.opacity(0.75)
    }
    private var centerFill: Color {
        colorScheme == .dark ? Color(red: 0.11, green: 0.12, blue: 0.15) : .white.opacity(0.55)
    }
    private var wedgeFill: Color {
        colorScheme == .dark ? Color(red: 0.28, green: 0.30, blue: 0.38) : .black.opacity(0.06)
    }
    private var borderStroke: Color {
        colorScheme == .dark ? Color(red: 0.28, green: 0.30, blue: 0.35) : .white.opacity(0.5)
    }
    private var innerStroke: Color {
        colorScheme == .dark ? Color(red: 0.22, green: 0.23, blue: 0.28) : .primary.opacity(0.06)
    }

    private var sliceAngleDeg: Double {
        let count = appState.settings.apps.count
        return count > 0 ? 360.0 / Double(count) : 360.0
    }

    private func angleForIndex(_ index: Int) -> Double {
        90.0 - sliceAngleDeg * Double(index)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ringLayer
            wedgeLayer
            innerCircleLayer
            centerContent
            iconsLayer
        }
        .frame(width: Self.windowSize, height: Self.windowSize)
        .drawingGroup()
        // 整体出入场：弹性缩放
        .scaleEffect(appState.isMenuVisible ? 1.0 : 0.25)
        .opacity(appState.isMenuVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appState.isMenuVisible)
        .onChange(of: appState.selectedIndex) { newIndex in
            handleSelectionChange(newIndex)
        }
        .onChange(of: appState.isMenuVisible) { visible in
            if !visible { showWedge = false }
        }
    }

    // MARK: - Ring

    @ViewBuilder
    private var ringLayer: some View {
        // 阴影 — 柔和渐隐
        Circle()
            .fill(
                RadialGradient(
                    stops: colorScheme == .dark ? [
                        .init(color: .black.opacity(0.25), location: 0.0),
                        .init(color: .black.opacity(0.12), location: 0.4),
                        .init(color: .black.opacity(0.04), location: 0.75),
                        .init(color: .clear, location: 1.0),
                    ] : [
                        .init(color: .black.opacity(0.06), location: 0.0),
                        .init(color: .black.opacity(0.03), location: 0.5),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: .center,
                    startRadius: outerRadius,
                    endRadius: outerRadius + 50
                )
            )
            .frame(width: outerRadius * 2 + 100, height: outerRadius * 2 + 100)

        // 外环
        Circle()
            .fill(ringFill)
            .frame(width: outerRadius * 2, height: outerRadius * 2)

        // 边框（深色下上亮下暗，模拟光照）
        Circle()
            .stroke(borderStroke, lineWidth: 0.5)
            .frame(width: outerRadius * 2, height: outerRadius * 2)
    }

    // MARK: - Wedge (丝滑旋转)

    @ViewBuilder
    private var wedgeLayer: some View {
        WedgeShape(
            midAngle: wedgeAngle,
            sliceAngle: sliceAngleDeg,
            innerRadius: innerRadius + 1,
            outerRadius: outerRadius - 1
        )
        .fill(wedgeFill)
        .frame(width: outerRadius * 2, height: outerRadius * 2)
        .opacity(showWedge ? 1 : 0)
        .allowsHitTesting(false)
    }

    // MARK: - Inner Circle (呼吸脉冲)

    @ViewBuilder
    private var innerCircleLayer: some View {
        Circle()
            .fill(centerFill)
            .frame(width: innerRadius * 2, height: innerRadius * 2)
            .scaleEffect(appState.selectedIndex != nil ? 1.04 : 1.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.55), value: appState.selectedIndex != nil)

        Circle()
            .stroke(innerStroke, lineWidth: 0.5)
            .frame(width: innerRadius * 2, height: innerRadius * 2)
    }

    // MARK: - Icons (级联入场 + 弹性选中)

    @ViewBuilder
    private var iconsLayer: some View {
        ForEach(Array(appState.settings.apps.enumerated()), id: \.element.id) { index, app in
            let total = appState.settings.apps.count
            let angle = (2 * Double.pi / Double(total)) * Double(index) - .pi / 2
            let x = center + iconOrbitRadius * cos(angle)
            let y = center - iconOrbitRadius * sin(angle)
            let isSelected = appState.selectedIndex == index
            let pushDistance: CGFloat = 10

            ZStack {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)

                // 运行中指示点
                if app.isRunning {
                    Circle()
                        .fill(.primary)
                        .frame(width: 4, height: 4)
                        .offset(y: iconSize / 2 + 6)
                }
            }
            // 选中动画：放大 + 沿径向外弹（液态弹出感）
            .scaleEffect(isSelected ? 1.25 : 1.0)
            .offset(
                x: isSelected ? cos(angle) * pushDistance : 0,
                y: isSelected ? -sin(angle) * pushDistance : 0
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.45), value: isSelected)
            // 入场动画：级联弹出（水滴溅射）
            .scaleEffect(appState.isMenuVisible ? 1.0 : 0.01)
            .opacity(appState.isMenuVisible ? 1.0 : 0.0)
            .animation(
                appState.isMenuVisible
                    ? .spring(response: 0.5, dampingFraction: 0.55).delay(Double(index) * 0.035)
                    : .spring(response: 0.22, dampingFraction: 0.85),
                value: appState.isMenuVisible
            )
            .position(x: x, y: y)
        }
    }

    // MARK: - Center Content

    private var selectedAppName: String {
        if let index = appState.selectedIndex, index < appState.settings.apps.count {
            return appState.settings.apps[index].displayName
        }
        return ""
    }

    @ViewBuilder
    var centerContent: some View {
        ZStack {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .opacity(appState.selectedIndex == nil ? 1 : 0)
                .scaleEffect(appState.selectedIndex == nil ? 1.0 : 0.4)

            Text(selectedAppName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(colorScheme == .dark ? Color(red: 0.22, green: 0.23, blue: 0.28) : .white.opacity(0.7))
                )
                .overlay(
                    Capsule().stroke(borderStroke, lineWidth: 0.5)
                )
                .opacity(appState.selectedIndex != nil ? 1 : 0)
                .scaleEffect(appState.selectedIndex != nil ? 1.0 : 0.6)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: appState.selectedIndex != nil)
    }

    // MARK: - Selection (最短路径旋转)

    private func handleSelectionChange(_ newIndex: Int?) {
        if let index = newIndex {
            let target = angleForIndex(index)
            if !showWedge {
                // 首次选中 → 直接定位 + 弹入
                wedgeAngle = target
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showWedge = true
                }
            } else {
                // 后续切换 → 沿最短弧线滑动
                var delta = target - wedgeAngle
                delta = delta.truncatingRemainder(dividingBy: 360)
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    wedgeAngle += delta
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.12)) {
                showWedge = false
            }
        }
    }
}
