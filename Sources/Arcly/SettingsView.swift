import SwiftUI
import AppKit
import ServiceManagement

private enum SettingsTab: String, CaseIterable, Identifiable {
    case apps
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apps: return Loc.string("settings.tab.wheel")
        case .general: return Loc.string("settings.tab.general")
        }
    }

    var subtitle: String {
        switch self {
        case .apps: return Loc.string("settings.tab.wheel.subtitle")
        case .general: return Loc.string("settings.tab.general.subtitle")
        }
    }

    var symbol: String {
        switch self {
        case .apps: return "square.grid.3x3"
        case .general: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedTab: SettingsTab = .apps

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selectedTab: $selectedTab)

            Divider()

            settingsContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 800, height: 420)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedTab {
        case .apps:
            AppsSettingsView()
                .environmentObject(appState)
        case .general:
            GeneralSettingsView()
                .environmentObject(appState)
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            selectedTab = tab
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(width: 150)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }
}

private struct SettingsSidebarButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(tab.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? .secondary : .tertiary)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - 应用设置

struct AppsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAppPicker = false
    @State private var selectedIndex: Int? = nil
    @State private var draggingIndex: Int? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var dragTargetIndex: Int? = nil
    @State private var isInDeleteZone: Bool = false

    @Namespace private var settingsGlassNS

    private let pieSize: CGFloat = 430
    private var previewMenuRadius: CGFloat { appState.settings.menuRadius }
    private var previewOuterDiameter: CGFloat { (previewMenuRadius + 50) * 2 }
    private var scale: CGFloat {
        min((pieSize - 28) / previewOuterDiameter, 1.12)
    }
    private var iconOrbitRadius: CGFloat { previewMenuRadius * scale }
    private var ringThickness: CGFloat { 100 * scale }
    private var outerRadius: CGFloat { iconOrbitRadius + ringThickness / 2 }
    private var innerRadius: CGFloat { iconOrbitRadius - ringThickness / 2 }
    private var center: CGFloat { pieSize / 2 }
    private var iconSize: CGFloat { appState.settings.iconSize * scale }
    private var menuGlassOpacity: Double {
        min(max(appState.settings.menuOpacity, 0.15), 1.0)
    }
    private var glassSurfaceFillOpacity: Double {
        let normalized = (menuGlassOpacity - 0.15) / 0.85
        return 0.03 + normalized * 0.42
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            appsPreviewPane
            appsControlPane
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(appState: appState, isPresented: $showingAppPicker)
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
                .environmentObject(appState)
        }
    }

    // MARK: - 底部按钮

    private var maxSlots: Int { appState.pro.maxSlots }

    private func addFileOrFolder() {
        guard appState.settings.apps.count < maxSlots else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.prompt = Loc.string("openPanel.add")
        panel.message = Loc.string("openPanel.fileOrFolder.message")
        if panel.runModal() == .OK, let url = panel.url {
            let bookmarkData = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let item = AppItem(
                name: url.lastPathComponent,
                bundleIdentifier: "",
                path: url.path,
                itemType: .fileOrFolder,
                bookmarkData: bookmarkData,
                customIconData: AppItem.persistentCustomIconData(for: url)
            )
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appState.settings.apps.append(item)
            }
            IconCache.shared.invalidate()
        }
    }

    @State private var showUpgrade = false

    private var appsPreviewPane: some View {
        wheelStage
            .frame(width: 420, height: 420, alignment: .center)
    }

    private var wheelStage: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: pieSize, height: pieSize)
                .scaleEffect((pieSize + 34) / pieSize)
                .blur(radius: 26)
                .allowsHitTesting(false)

            pieRing
            pieIcons
        }
        .frame(width: pieSize, height: pieSize)
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                selectedIndex = nil
            }
        }
    }

    private var appsControlPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            controlList
        }
        .frame(width: 184)
    }

    private var controlList: some View {
        VStack(spacing: 0) {
            actionTile(
                Loc.string("settings.addApp"),
                subtitle: Loc.string("settings.addApp.subtitle"),
                icon: "plus.app"
            ) {
                if appState.settings.apps.count >= maxSlots && !appState.pro.isPro {
                    showUpgrade = true
                } else {
                    showingAppPicker = true
                }
            }
            .disabled(appState.settings.apps.count >= maxSlots && appState.pro.isPro)

            Divider()
                .padding(.leading, 44)

            actionTile(
                Loc.string("settings.addFolder"),
                subtitle: appState.pro.canAddFolder ? Loc.string("settings.addFolder.subtitle") : Loc.string("settings.proUnlock"),
                icon: "folder.badge.plus",
                badge: appState.pro.isPro ? nil : "PRO"
            ) {
                if !appState.pro.canAddFolder {
                    showUpgrade = true
                } else {
                    addFileOrFolder()
                }
            }

            Divider()
                .padding(.leading, 44)

            actionTile(
                Loc.string("settings.restoreDefaults"),
                subtitle: Loc.string("settings.restoreDefaults.subtitle"),
                icon: "arrow.counterclockwise"
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    selectedIndex = nil
                    appState.settings.apps = Array(AppState.defaultApps().prefix(maxSlots))
                }
            }
        }
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }

    private func actionTile(
        _ title: String,
        subtitle: String,
        icon: String,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(height: 58)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 圆环

    private var pieRing: some View {
        ZStack {
            GlassEffectContainer {
                ZStack {
                    settingsGlassSurfaceLayer

                    Color.clear
                        .frame(width: outerRadius * 2, height: outerRadius * 2)
                        .glassEffect(.regular.interactive(), in: DonutShape(
                            innerRadius: innerRadius,
                            outerRadius: outerRadius
                        ))
                        .glassEffectID("settingsRing", in: settingsGlassNS)
                        .opacity(menuGlassOpacity)

                    Color.clear
                        .frame(width: innerRadius * 2 + 4, height: innerRadius * 2 + 4)
                        .glassEffect(.regular, in: .circle)
                        .glassEffectID("settingsCenter", in: settingsGlassNS)
                        .scaleEffect(selectedIndex != nil ? 1.04 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5),
                                   value: selectedIndex != nil)
                        .opacity(menuGlassOpacity)

                    settingsGlassRefractionLayer
                }
            }

            centerLabel
        }
    }

    @ViewBuilder
    private var settingsGlassSurfaceLayer: some View {
        ZStack {
            DonutShape(innerRadius: innerRadius, outerRadius: outerRadius)
                .fill(Color.white.opacity(glassSurfaceFillOpacity))

            Circle()
                .fill(Color.white.opacity(glassSurfaceFillOpacity * 0.72))
                .frame(width: innerRadius * 2 + 4, height: innerRadius * 2 + 4)
        }
        .frame(width: outerRadius * 2, height: outerRadius * 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var settingsGlassRefractionLayer: some View {
        ZStack {
            DonutShape(innerRadius: innerRadius + 1, outerRadius: outerRadius - 1)
                .stroke(Color.white.opacity(0.24 * menuGlassOpacity), lineWidth: 1)
                .blur(radius: 0.3)

            DonutShape(innerRadius: innerRadius + 7, outerRadius: outerRadius - 7)
                .stroke(Color.black.opacity(0.045 * menuGlassOpacity), lineWidth: 5)
                .blur(radius: 4.5)
                .blendMode(.multiply)

            Circle()
                .stroke(Color.white.opacity(0.18 * menuGlassOpacity), lineWidth: 1)
                .frame(width: innerRadius * 2 - 7, height: innerRadius * 2 - 7)
                .blur(radius: 0.3)

            Circle()
                .stroke(Color.black.opacity(0.04 * menuGlassOpacity), lineWidth: 4.5)
                .frame(width: innerRadius * 2 - 18, height: innerRadius * 2 - 18)
                .blur(radius: 4.5)
                .blendMode(.multiply)
        }
        .frame(width: outerRadius * 2, height: outerRadius * 2)
        .allowsHitTesting(false)
    }

    // MARK: - 中心标签

    @ViewBuilder
    private var centerLabel: some View {
        ZStack {
            // 1. 删除区激活（拖到中心）
            if isInDeleteZone {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 26, weight: .semibold))
                    Text(Loc.string("wheel.releaseToDelete"))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.red)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            // 2. 拖拽中（未进入删除区）
            else if draggingIndex != nil {
                VStack(spacing: 2) {
                    Text(Loc.string("wheel.dragToCenter"))
                        .font(.system(size: 10))
                    Text(Loc.string("wheel.delete"))
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }
            // 3. 选中状态（点击图标）
            else if let idx = selectedIndex, idx < appState.settings.apps.count {
                Text(appState.settings.apps[idx].displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .transition(.scale(scale: 0.75).combined(with: .opacity))
            }
            // 4. 空状态
            else if appState.settings.apps.isEmpty {
                Text(Loc.string("wheel.addAppsHint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            // 5. 默认提示
            else {
                VStack(spacing: 2) {
                    Text(Loc.string("wheel.dragToReorder"))
                        .font(.system(size: 10))
                    Text(Loc.string("wheel.dragToCenterDelete"))
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedIndex)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isInDeleteZone)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: draggingIndex)
    }

    // MARK: - 图标

    private var previewOrder: [Int] {
        let total = appState.settings.apps.count
        guard let from = draggingIndex, let to = dragTargetIndex,
              from != to, from < total, to < total else {
            return Array(0..<total)
        }
        var order = Array(0..<total)
        let item = order.remove(at: from)
        order.insert(item, at: to)
        return order
    }

    private var pieIcons: some View {
        let apps = appState.settings.apps
        let total = apps.count
        let preview = previewOrder
        return ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
            let displaySlot = preview.firstIndex(of: index) ?? index
            pieIcon(app: app, index: index, displaySlot: displaySlot, total: total)
        }
    }

    private func slotPosition(slot: Int, total: Int) -> (x: CGFloat, y: CGFloat) {
        guard total > 0 else { return (center, center) }
        let angle = (2 * Double.pi / Double(total)) * Double(slot) - .pi / 2
        return (center + iconOrbitRadius * cos(angle), center - iconOrbitRadius * sin(angle))
    }

    private func pieIcon(app: AppItem, index: Int, displaySlot: Int, total: Int) -> some View {
        let originalPos = slotPosition(slot: index, total: total)
        let targetPos = slotPosition(slot: displaySlot, total: total)
        let isSelected = selectedIndex == index
        let isDragging = draggingIndex == index
        let angle = (2 * Double.pi / Double(max(total, 1))) * Double(index) - .pi / 2
        let pushDist: CGFloat = 6

        let posX = isDragging ? originalPos.x + dragTranslation.width : targetPos.x
        let posY = isDragging ? originalPos.y + dragTranslation.height : targetPos.y

        return ZStack {
            // 选中高亮圆 — 柔和的 tint 底色
            if isSelected && !isDragging {
                Circle()
                    .fill(.tint.opacity(0.1))
                    .frame(width: iconSize + 12, height: iconSize + 12)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .overlay {
                    if isDragging && isInDeleteZone {
                        Circle()
                            .fill(.red.opacity(0.45))
                            .overlay {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: iconSize * 0.35, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .transition(.opacity)
                    }
                }
        }
        .scaleEffect(isDragging ? (isInDeleteZone ? 0.85 : 1.2) : (isSelected ? 1.15 : 1.0))
        .offset(
            x: isSelected && !isDragging ? cos(angle) * pushDist : 0,
            y: isSelected && !isDragging ? -sin(angle) * pushDist : 0
        )
        .position(x: posX, y: posY)
        .zIndex(isDragging ? 10 : (isSelected ? 5 : 0))
        .gesture(dragGesture(index: index, total: total, originX: originalPos.x, originY: originalPos.y))
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                selectedIndex = selectedIndex == index ? nil : index
            }
        }
    }

    // MARK: - 拖拽手势

    private func dragGesture(index: Int, total: Int, originX: CGFloat, originY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if draggingIndex == nil {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        selectedIndex = nil
                        draggingIndex = index
                    }
                } else {
                    draggingIndex = index
                }
                dragTranslation = value.translation

                let absX = originX + value.translation.width
                let absY = originY + value.translation.height
                let distFromCenter = hypot(absX - center, absY - center)
                let inDelete = distFromCenter < innerRadius

                if inDelete != isInDeleteZone {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isInDeleteZone = inDelete
                    }
                }

                if inDelete {
                    // 进入删除区时取消排序预览
                    if dragTargetIndex != nil {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragTargetIndex = nil
                        }
                    }
                } else {
                    let target = slotIndex(at: CGPoint(x: absX, y: absY), total: total)
                    if target != dragTargetIndex {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragTargetIndex = target
                        }
                    }
                }
            }
            .onEnded { value in
                let absX = originX + value.translation.width
                let absY = originY + value.translation.height
                let distFromCenter = hypot(absX - center, absY - center)
                let inDelete = distFromCenter < innerRadius
                let target = slotIndex(at: CGPoint(x: absX, y: absY), total: total)

                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if inDelete {
                        // 拖到中心 → 删除
                        appState.settings.apps.remove(at: index)
                    } else if target != index {
                        // 拖到其它槽位 → 重新排序
                        let item = appState.settings.apps.remove(at: index)
                        let insertAt = min(target, appState.settings.apps.count)
                        appState.settings.apps.insert(item, at: insertAt)
                    }
                    draggingIndex = nil
                    dragTranslation = .zero
                    dragTargetIndex = nil
                    isInDeleteZone = false
                }
            }
    }

    private func slotIndex(at point: CGPoint, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let dx = Double(point.x - center)
        let dy = Double(center - point.y)
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        let sliceAngle = (2 * .pi) / Double(total)
        let adjusted = fmod(angle + .pi / 2 + sliceAngle / 2, 2 * .pi)
        return Int(adjusted / sliceAngle) % total
    }
}

// MARK: - 应用选择器

struct AppPickerView: View {
    let appState: AppState
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var installedApps: [AppItem] = []
    @State private var recentlyAdded: Set<String> = []

    var filteredApps: [AppItem] {
        let existing = Set(appState.settings.apps.map { $0.bundleIdentifier })
        let available = installedApps.filter { !existing.contains($0.bundleIdentifier) }

        if searchText.isEmpty {
            return available
        }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(Loc.string("appPicker.title"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(Loc.string("appPicker.done")) { isPresented = false }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.defaultAction)
            }

            SearchField(text: $searchText, placeholder: Loc.string("appPicker.search"))

            List(filteredApps) { app in
                let justAdded = recentlyAdded.contains(app.bundleIdentifier)
                HStack(spacing: 12) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.displayName)
                            .font(.system(size: 13))
                        if app.displayName != app.name {
                            Text(app.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    if justAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: { addApp(app) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.settings.apps.count >= appState.pro.maxSlots)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .padding(20)
        .frame(width: 420, height: 500)
        .onAppear {
            installedApps = AppState.installedApps()
        }
    }

    func addApp(_ app: AppItem) {
        guard appState.settings.apps.count < appState.pro.maxSlots else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            appState.settings.apps.append(app)
            recentlyAdded.insert(app.bundleIdentifier)
        }
        // 短暂显示勾后从列表移除
        let bid = app.bundleIdentifier
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.25)) {
                _ = recentlyAdded.remove(bid)
            }
        }
    }
}

// MARK: - 通用设置

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 5)

            content
        }
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }
}

private struct SettingRow<Accessory: View>: View {
    let title: String
    var locked: Bool = false
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if locked {
                    Text("PRO")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            .foregroundStyle(locked ? .secondary : .primary)

            Spacer(minLength: 8)
            accessory
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
    }
}

private struct SettingDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 10)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var launchAtLogin = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            primaryColumn
            secondaryColumn
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            launchAtLogin = getLaunchAtLogin()
        }
    }

    private var primaryColumn: some View {
        VStack(spacing: 12) {
            triggerGroup
            playbackGroup
        }
        .frame(width: 292)
    }

    private var secondaryColumn: some View {
        VStack(spacing: 12) {
            wheelGroup
            systemGroup
        }
        .frame(width: 292)
    }

    private var triggerGroup: some View {
        SettingsGroup(title: Loc.string("settings.group.trigger")) {
            HotkeyRecorderRow(appState: appState)

            SettingDivider()

            SettingRow(title: Loc.string("settings.mouse"), locked: !appState.pro.isPro) {
                Picker("", selection: $appState.settings.mouseTrigger) {
                    ForEach(MouseTrigger.allCases, id: \.self) { trigger in
                        Text(trigger.displayName).tag(trigger)
                    }
                }
                .labelsHidden()
                .frame(width: 112)
                .disabled(!appState.pro.isPro)
                .onChange(of: appState.settings.mouseTrigger) { _ in
                    NotificationCenter.default.post(name: .mouseTriggerChanged, object: nil)
                }
            }

            SettingDivider()

            SettingRow(title: Loc.string("settings.mode")) {
                Picker("", selection: $appState.settings.interactionMode) {
                    Text(Loc.string("mode.click")).tag(InteractionMode.click)
                    Text(Loc.string("mode.hold")).tag(InteractionMode.hold)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 112)
            }
        }
    }

    private var playbackGroup: some View {
        SettingsGroup(title: Loc.string("settings.group.playback")) {
            SettingRow(title: Loc.string("settings.nowPlaying")) {
                Toggle("", isOn: $appState.settings.showMusicControl)
                    .labelsHidden()
            }

            SettingDivider()

            SettingRow(title: Loc.string("settings.playbackControls"), locked: !appState.pro.isPro) {
                Toggle("", isOn: .constant(appState.pro.canControlMusic))
                    .labelsHidden()
                    .disabled(!appState.pro.isPro)
            }

            SettingDivider()

            SettingRow(title: Loc.string("settings.haptics")) {
                Toggle("", isOn: $appState.settings.hapticFeedback)
                    .labelsHidden()
            }

            SettingDivider()

            SettingRow(title: Loc.string("settings.sound")) {
                Toggle("", isOn: $appState.settings.soundEffects)
                    .labelsHidden()
            }
        }
    }

    private var wheelGroup: some View {
        SettingsGroup(title: Loc.string("settings.group.wheel")) {
            SettingRow(title: Loc.string("settings.position")) {
                Picker("", selection: $appState.settings.menuPosition) {
                    Text(Loc.string("position.mouse")).tag(MenuPosition.followMouse)
                    Text(Loc.string("position.center")).tag(MenuPosition.screenCenter)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 112)
            }

            SettingDivider()

            SettingRow(title: Loc.string("settings.theme")) {
                Picker("", selection: $appState.settings.appearanceMode) {
                    Text(Loc.string("theme.system")).tag(AppearanceMode.system)
                    Text(Loc.string("theme.light")).tag(AppearanceMode.light)
                    Text(Loc.string("theme.dark")).tag(AppearanceMode.dark)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 124)
                .onChange(of: appState.settings.appearanceMode) { _ in
                    NotificationCenter.default.post(name: .appearanceChanged, object: nil)
                }
            }

            SettingDivider()

            sliderRow(
                title: Loc.string("settings.radius"),
                value: $appState.settings.menuRadius,
                range: 100...180,
                step: 10,
                locked: !appState.pro.isPro
            )

            SettingDivider()

            sliderRow(
                title: Loc.string("settings.icon"),
                value: $appState.settings.iconSize,
                range: 32...64,
                step: 4,
                locked: !appState.pro.isPro
            )

            SettingDivider()

            opacitySliderRow(
                title: Loc.string("settings.opacity"),
                value: $appState.settings.menuOpacity,
                range: 0.15...1.0,
                step: 0.05
            )
        }
    }

    private var systemGroup: some View {
        SettingsGroup(title: Loc.string("settings.group.system")) {
            SettingRow(title: Loc.string("settings.launchAtLogin")) {
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            SettingDivider()

            SettingRow(title: Loc.string("settings.menuBar")) {
                Toggle("", isOn: $appState.settings.showMenuBarIcon)
                    .labelsHidden()
                    .onChange(of: appState.settings.showMenuBarIcon) { _ in
                        NotificationCenter.default.post(name: .menuBarIconChanged, object: nil)
                    }
            }
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        locked: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if locked {
                    Text("PRO")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: step)
                .disabled(locked)
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
    }

    private func opacitySliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(round(value.wrappedValue * 100)))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: step)
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
    }

    func getLaunchAtLogin() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("❌ 设置开机自启动失败: %@", error.localizedDescription)
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}

// MARK: - 快捷键录制

struct HotkeyRecorderRow: View {
    @ObservedObject var appState: AppState
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        HStack {
            Text(Loc.string("settings.hotkey"))
                .font(.system(size: 12, weight: .medium))
            Spacer()

            if isRecording {
                Text(Loc.string("hotkey.recording"))
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { startRecording() } }) {
                    HStack(spacing: 2) {
                        ForEach(modifierSymbols, id: \.self) { sym in
                            KeyCap(sym)
                        }
                        KeyCap(HotkeyConfig.keyCodeToString(appState.settings.hotkey.keyCode))
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
    }

    private var modifierSymbols: [String] {
        var result: [String] = []
        let mods = appState.settings.hotkey.modifiers
        if mods.contains(.control) { result.append("⌃") }
        if mods.contains(.option) { result.append("⌥") }
        if mods.contains(.shift) { result.append("⇧") }
        if mods.contains(.command) { result.append("⌘") }
        return result
    }

    private func startRecording() {
        stopRecording()
        NSApp.activate(ignoringOtherApps: true)
        isRecording = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyEvent(event)
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let mods = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .control, .option, .shift])

        guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
            if event.keyCode == 53 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    stopRecording()
                }
            }
            return
        }

        appState.settings.hotkey = HotkeyConfig(keyCode: event.keyCode, modifiers: mods)
        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            stopRecording()
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }
}

// MARK: - 按键帽组件

struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .frame(minWidth: 24, minHeight: 22)
            .padding(.horizontal, 4)
            .glassEffect(.regular, in: .rect(cornerRadius: 5))
    }
}

// MARK: - NSSearchField 包装

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        // sheet 窗口 IME 修复：激活 app + 让 sheet 成为 key window + 聚焦搜索框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = field.window {
                window.makeKey()
                window.makeFirstResponder(field)
            }
        }
        // 双重保障：延迟再试一次
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = field.window, window.firstResponder !== field.currentEditor() {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKey()
                window.makeFirstResponder(field)
            }
        }
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: SearchField
        init(_ parent: SearchField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}

// MARK: - 交互模式

extension InteractionMode {
    var displayName: String {
        switch self {
        case .hold: return Loc.string("mode.holdDescription")
        case .click: return Loc.string("mode.clickDescription")
        }
    }
}

// MARK: - 升级 Pro

struct UpgradeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(Loc.string("upgrade.title"))
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "square.grid.3x3.fill", text: Loc.string("upgrade.feature.slots"))
                featureRow(icon: "folder.fill", text: Loc.string("upgrade.feature.folder"))
                featureRow(icon: "slider.horizontal.3", text: Loc.string("upgrade.feature.size"))
                featureRow(icon: "play.circle.fill", text: Loc.string("upgrade.feature.music"))
                featureRow(icon: "computermouse.fill", text: Loc.string("upgrade.feature.mouse"))
            }
            .padding(.horizontal, 20)

            switch appState.pro.loadState {
            case .loaded:
                if let product = appState.pro.product {
                    Button(action: {
                        Task { await appState.pro.purchase() }
                    }) {
                        HStack {
                            if appState.pro.purchaseInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(Loc.string("upgrade.buy", product.displayPrice))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.pro.purchaseInProgress)
                    .padding(.horizontal, 40)
                }
            case .loading:
                ProgressView(Loc.string("upgrade.loading"))
            case .failed(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(Loc.string("upgrade.retry")) {
                        Task { await appState.pro.loadProduct() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 40)
            }

            Button(Loc.string("upgrade.restore")) {
                Task { await appState.pro.restore() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            Button(Loc.string("upgrade.cancel")) { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 360)
        .onChange(of: appState.pro.isPro) { isPro in
            if isPro { dismiss() }
        }
    }

    func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
        }
    }
}
