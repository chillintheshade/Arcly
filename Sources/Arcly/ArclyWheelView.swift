import SwiftUI
import AppKit

// MARK: - Selection Wedge Shape

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

// MARK: - Donut Shape

struct DonutShape: Shape {
    var innerRadius: CGFloat
    var outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: c, radius: outerRadius,
                 startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        p.addArc(center: c, radius: innerRadius,
                 startAngle: .zero, endAngle: .degrees(360), clockwise: true)
        return p
    }
}

// MARK: - Motion

private struct LiquidContentTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: blur)
    }
}

enum MenuMotion {
    static let appearResponse: Double = 0.24
    static let dismissResponse: Double = 0.28
    static let dismissOrderOutDelay: Double = 0.34
    static let iconFocusResponse: Double = 0.18
    static let centerSwapResponse: Double = 0.16

    static let hiddenScaleX: CGFloat = 0.90
    static let hiddenScaleY: CGFloat = 0.94
    static let menuHiddenBlur: CGFloat = 7
    static let hiddenOpacity: Double = 0.02

    static let iconSelectedScale: CGFloat = 1.07
    static let iconSelectedPushRatio: CGFloat = 0.018
    static let selectedDotScale: CGFloat = 1.62
    static let iconEntryMaxDelay: Double = 0.06

    static func menuAnimation(isVisible: Bool) -> Animation {
        isVisible
            ? .spring(response: appearResponse, dampingFraction: 0.7)
            : .spring(response: dismissResponse, dampingFraction: 0.95)
    }

    static var iconFocusAnimation: Animation {
        .spring(response: iconFocusResponse, dampingFraction: 0.68)
    }

    static var centerAnimation: Animation {
        .spring(response: centerSwapResponse, dampingFraction: 0.78)
    }

    static var wedgeSelectionAnimation: Animation {
        .easeOut(duration: 0.14)
    }

    static var centerContentTransition: AnyTransition {
        .modifier(
            active: LiquidContentTransitionModifier(opacity: 0, scale: 0.965, blur: 3),
            identity: LiquidContentTransitionModifier(opacity: 1, scale: 1, blur: 0)
        )
    }
}

// MARK: - ArclyWheelView

struct ArclyWheelView: View {
    @ObservedObject var appState: AppState
    var onAppSelected: ((AppItem) -> Void)?
    var onSettingsTapped: (() -> Void)?

    static let windowSize: CGFloat = 480

    @Namespace private var glassNS
    @State private var wedgeAngle: Double = 90
    @State private var showWedge: Bool = false

    init(appState: AppState,
         onAppSelected: ((AppItem) -> Void)? = nil,
         onSettingsTapped: (() -> Void)? = nil) {
        self.appState = appState
        self.nowPlaying = appState.nowPlaying
        self.onAppSelected = onAppSelected
        self.onSettingsTapped = onSettingsTapped
    }

    private var iconOrbitRadius: CGFloat { appState.settings.menuRadius }
    private var ringThickness: CGFloat { 100 }
    private var outerRadius: CGFloat { iconOrbitRadius + ringThickness / 2 }
    private var innerRadius: CGFloat { iconOrbitRadius - ringThickness / 2 }
    private var center: CGFloat { Self.windowSize / 2 }
    private var iconSize: CGFloat { appState.settings.iconSize }
    private var menuGlassOpacity: Double {
        min(max(appState.settings.menuOpacity, 0.15), 1.0)
    }
    private var glassSurfaceFillOpacity: Double {
        let normalized = (menuGlassOpacity - 0.15) / 0.85
        return 0.03 + normalized * 0.42
    }
    private var centerLensRadius: CGFloat {
        let maxRadiusBeforeIcons = iconOrbitRadius - iconSize / 2 - 10
        return min(max(innerRadius, 66), maxRadiusBeforeIcons)
    }
    private var centerControlScale: CGFloat {
        min(max(iconOrbitRadius / 130, 0.88), 1.42)
    }
    private var centerMusicControlScale: CGFloat {
        let radiusScale = centerControlScale
        let availableScale = (centerLensRadius * 2 - 18) / 142
        return min(radiusScale, max(0.68, availableScale))
    }
    private var centerSettingsIconSize: CGFloat { 24 * centerControlScale }
    private var musicArtworkBaseSize: CGFloat { 58 }
    private var musicArtworkSize: CGFloat { musicArtworkBaseSize * centerMusicControlScale }
    private var musicArtworkCornerRadius: CGFloat { 12 }
    private var musicTitleFontSize: CGFloat { 11.5 * centerMusicControlScale }
    private var musicSecondaryControlSize: CGFloat { 15 * centerMusicControlScale }
    private var musicPrimaryControlSize: CGFloat { 22 * centerMusicControlScale }
    private var musicControlSpacing: CGFloat { 18 * centerMusicControlScale }
    private var musicVerticalGap: CGFloat { 8 * centerMusicControlScale }
    private var musicControllerWidth: CGFloat {
        min(min(max(iconOrbitRadius * 1.28, 142), 230), max(centerLensRadius * 2 - 18, 96))
    }

    private var sliceAngleDeg: Double {
        let count = appState.settings.apps.count
        return count > 0 ? 360.0 / Double(count) : 360.0
    }

    private func angleForIndex(_ index: Int) -> Double {
        90.0 - sliceAngleDeg * Double(index)
    }

    private func normalizedAngleDelta(from current: Double, to target: Double) -> Double {
        var delta = (target - current).truncatingRemainder(dividingBy: 360)
        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }
        return delta
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. Glass 圆环
            GlassEffectContainer {
                ZStack {
                    glassSurfaceLayer

                    Color.clear
                        .frame(width: outerRadius * 2, height: outerRadius * 2)
                        .glassEffect(.regular.interactive(), in: DonutShape(
                            innerRadius: innerRadius,
                            outerRadius: outerRadius
                        ))
                        .glassEffectID("ring", in: glassNS)
                        .opacity(menuGlassOpacity)

                    Color.clear
                        .frame(width: centerLensRadius * 2 + 4, height: centerLensRadius * 2 + 4)
                        .glassEffect(.regular, in: .circle)
                        .glassEffectID("center", in: glassNS)
                        .scaleEffect(appState.selectedIndex != nil ? 1.05 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5),
                                   value: appState.selectedIndex != nil)
                        .opacity(menuGlassOpacity)

                    glassRefractionLayer
                }
            }

            // 2. 选中扇形 — tinted glass
            selectedWedgeLayer

            // 3. 中心内容
            centerContent

            // 4. 图标
            iconsLayer
        }
        .frame(width: Self.windowSize, height: Self.windowSize)
        // 入场/收起只改变运动，不改变已有 glassEffect 材质。
        .scaleEffect(x: appState.isMenuVisible ? 1.0 : MenuMotion.hiddenScaleX,
            y: appState.isMenuVisible ? 1.0 : MenuMotion.hiddenScaleY,
            anchor: .center
        )
        .opacity(appState.isMenuVisible ? 1.0 : MenuMotion.hiddenOpacity)
        .blur(radius: appState.isMenuVisible ? 0 : MenuMotion.menuHiddenBlur)
        .animation(MenuMotion.menuAnimation(isVisible: appState.isMenuVisible),
                   value: appState.isMenuVisible)
        .onChange(of: appState.selectedIndex) { newIndex in
            handleSelectionChange(newIndex)
        }
        .onChange(of: appState.isMenuVisible) { visible in
            if !visible {
                withAnimation(.easeOut(duration: 0.08)) {
                    showWedge = false
                }
            }
        }
    }

    // MARK: - Selection Wedge

    @ViewBuilder
    private var glassSurfaceLayer: some View {
        ZStack {
            DonutShape(innerRadius: innerRadius, outerRadius: outerRadius)
                .fill(Color.white.opacity(glassSurfaceFillOpacity))

            Circle()
                .fill(Color.white.opacity(glassSurfaceFillOpacity * 0.72))
                .frame(width: centerLensRadius * 2 + 4, height: centerLensRadius * 2 + 4)
        }
        .frame(width: outerRadius * 2, height: outerRadius * 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var glassRefractionLayer: some View {
        ZStack {
            DonutShape(innerRadius: innerRadius + 1, outerRadius: outerRadius - 1)
                .stroke(Color.white.opacity(0.24 * menuGlassOpacity), lineWidth: 1.1)
                .blur(radius: 0.35)

            DonutShape(innerRadius: innerRadius + 7, outerRadius: outerRadius - 7)
                .stroke(Color.black.opacity(0.045 * menuGlassOpacity), lineWidth: 5.5)
                .blur(radius: 5)
                .blendMode(.multiply)

            Circle()
                .stroke(Color.white.opacity(0.18 * menuGlassOpacity), lineWidth: 1)
                .frame(width: centerLensRadius * 2 - 7, height: centerLensRadius * 2 - 7)
                .blur(radius: 0.35)

            Circle()
                .stroke(Color.black.opacity(0.04 * menuGlassOpacity), lineWidth: 5)
                .frame(width: centerLensRadius * 2 - 18, height: centerLensRadius * 2 - 18)
                .blur(radius: 5)
                .blendMode(.multiply)
        }
        .frame(width: outerRadius * 2, height: outerRadius * 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var selectedWedgeLayer: some View {
        if showWedge {
            WedgeShape(
                midAngle: wedgeAngle,
                sliceAngle: sliceAngleDeg,
                innerRadius: innerRadius + 3,
                outerRadius: outerRadius - 3
            )
            .fill(Color.accentColor.opacity(0.12))
            .frame(width: outerRadius * 2, height: outerRadius * 2)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    // MARK: - Icons

    @ViewBuilder
    private var iconsLayer: some View {
        ForEach(Array(appState.settings.apps.enumerated()), id: \.element.id) { index, app in
            let total = appState.settings.apps.count
            let angle = (2 * Double.pi / Double(total)) * Double(index) - .pi / 2
            let x = center + iconOrbitRadius * cos(angle)
            let y = center - iconOrbitRadius * sin(angle)
            let isSelected = appState.selectedIndex == index
            let pushDist = iconOrbitRadius * MenuMotion.iconSelectedPushRatio

            ZStack {
                selectedIconHalo(angle: angle, isSelected: isSelected)

                if app.itemType == .app {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        // App 图标保留圆角裁剪，避免 macOS 预渲染阴影外溢。
                        .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous))
                } else {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                }

                // 运行中指示点
                if app.isRunning {
                    Circle()
                        .fill(.primary)
                        .frame(width: 4, height: 4)
                        .scaleEffect(isSelected ? MenuMotion.selectedDotScale : 1.0)
                        .opacity(isSelected ? 1.0 : 0.85)
                        .offset(y: iconSize / 2 + 6)
                        .animation(MenuMotion.iconFocusAnimation, value: isSelected)
                }
            }
            // 选中：轻微放大 + 沿径向外浮，像焦点压过玻璃表面。
            .scaleEffect(isSelected ? MenuMotion.iconSelectedScale : 1.0)
            .offset(
                x: isSelected ? cos(angle) * pushDist : 0,
                y: isSelected ? -sin(angle) * pushDist : 0
            )
            .animation(MenuMotion.iconFocusAnimation, value: isSelected)
            // 入场：级联弹出
            .scaleEffect(appState.isMenuVisible ? 1.0 : 0.86)
            .opacity(appState.isMenuVisible ? 1.0 : 0.0)
            .blur(radius: appState.isMenuVisible ? 0 : 3)
            .animation(
                appState.isMenuVisible
                    ? .spring(response: 0.26, dampingFraction: 0.74)
                        .delay(min(Double(index) * 0.012, MenuMotion.iconEntryMaxDelay))
                    : .spring(response: MenuMotion.dismissResponse, dampingFraction: 0.95),
                value: appState.isMenuVisible
            )
            .position(x: x, y: y)
        }
    }

    @ViewBuilder
    private func selectedIconHalo(angle: Double, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: iconSize * 0.42, style: .continuous)
            .fill(.white.opacity(0.32))
            .frame(width: iconSize + 26, height: iconSize + 26)
            .blur(radius: 9)
            .opacity(isSelected ? 0.42 : 0)
            .scaleEffect(isSelected ? 1.0 : 0.72)
            .offset(
                x: isSelected ? cos(angle) * iconOrbitRadius * MenuMotion.iconSelectedPushRatio * 0.45 : 0,
                y: isSelected ? -sin(angle) * iconOrbitRadius * MenuMotion.iconSelectedPushRatio * 0.45 : 0
            )
            .allowsHitTesting(false)
            .animation(MenuMotion.iconFocusAnimation, value: isSelected)
    }

    // MARK: - Center Content

    private var selectedAppName: String {
        if let index = appState.selectedIndex, index < appState.settings.apps.count {
            return appState.settings.apps[index].displayName
        }
        return ""
    }

    private var centerContentIdentity: String {
        if let index = appState.selectedIndex, index < appState.settings.apps.count {
            return "app-\(appState.settings.apps[index].id)"
        }

        let np = nowPlaying
        if np.hasNowPlaying && appState.settings.showMusicControl {
            return "music-\(np.trackName)-\(np.artistName)-\(np.isPlaying)"
        }

        return "settings"
    }

    @ObservedObject private var nowPlaying: NowPlayingService

    @ViewBuilder
    var centerContent: some View {
        let np = nowPlaying
        let noSelection = appState.selectedIndex == nil
        let hasMusic = np.hasNowPlaying && appState.settings.showMusicControl

        ZStack {
            // 状态 1: 无音乐 + 未选中 → 齿轮
            if noSelection && !hasMusic {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: centerSettingsIconSize, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .transition(MenuMotion.centerContentTransition)
            }

            // 状态 2: 有音乐 + 未选中 → 音乐控制器
            if noSelection && hasMusic {
                musicController
                    .transition(MenuMotion.centerContentTransition)
            }

            // 状态 3: 选中应用 → 应用名
            if !noSelection {
                Text(selectedAppName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .transition(MenuMotion.centerContentTransition)
            }
        }
        .animation(MenuMotion.centerAnimation, value: centerContentIdentity)
    }

    // MARK: - Music Controller

    @ViewBuilder
    private var musicController: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: musicVerticalGap)

            // 专辑封面
            if let art = nowPlaying.albumArt {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: musicArtworkSize, height: musicArtworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: musicArtworkCornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: musicArtworkCornerRadius, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: musicArtworkSize, height: musicArtworkSize)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 24 * centerMusicControlScale, weight: .medium))
                            .foregroundStyle(.tertiary)
                    )
            }

            Spacer().frame(height: musicVerticalGap * 0.75)

            // 曲名 - 歌手
            Group {
                if nowPlaying.trackName.isEmpty {
                    Text(Loc.string("music.placeholder"))
                        .foregroundStyle(.tertiary)
                } else if nowPlaying.artistName.isEmpty {
                    Text(nowPlaying.trackName)
                        .foregroundColor(.primary)
                } else {
                    Text("\(nowPlaying.trackName) - \(nowPlaying.artistName)")
                        .foregroundColor(.primary)
                }
            }
            .font(.system(size: musicTitleFontSize, weight: .medium))
            .lineLimit(1)
            .frame(width: musicControllerWidth)

            Spacer().frame(height: musicVerticalGap)

            // 播放控制（Pro 功能）
            if appState.pro.canControlMusic {
                HStack(spacing: musicControlSpacing) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: musicSecondaryControlSize))
                        .foregroundStyle(.secondary)

                    Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: musicPrimaryControlSize))
                        .foregroundStyle(.primary)

                    Image(systemName: "forward.fill")
                        .font(.system(size: musicSecondaryControlSize))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer().frame(height: musicVerticalGap)

            // 设置齿轮
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12.5 * centerMusicControlScale, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Selection

    private func handleSelectionChange(_ newIndex: Int?) {
        if let index = newIndex {
            let target = angleForIndex(index)
            if !showWedge {
                wedgeAngle = target
                withAnimation(.easeOut(duration: 0.08)) {
                    showWedge = true
                }
            } else {
                let delta = normalizedAngleDelta(from: wedgeAngle, to: target)
                withAnimation(MenuMotion.wedgeSelectionAnimation) {
                    wedgeAngle += delta
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.1)) {
                showWedge = false
            }
        }
    }
}
