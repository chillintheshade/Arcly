import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            AppsSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("应用", systemImage: "square.grid.3x3")
                }

            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 540)
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

    @Environment(\.colorScheme) var colorScheme

    private let pieSize: CGFloat = 340
    private var scale: CGFloat { pieSize / PieMenuView.windowSize }
    private var iconOrbitRadius: CGFloat { appState.settings.menuRadius * scale }
    private var ringThickness: CGFloat { 100 * scale }
    private var outerRadius: CGFloat { iconOrbitRadius + ringThickness / 2 }
    private var innerRadius: CGFloat { iconOrbitRadius - ringThickness / 2 }
    private var center: CGFloat { pieSize / 2 }
    private var iconSize: CGFloat { appState.settings.iconSize * scale }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                pieRing
                pieIcons
            }
            .frame(width: pieSize, height: pieSize)
            .onTapGesture {
                // 点击空白区域取消选中
                selectedIndex = nil
            }

            bottomBar
        }
        .padding(.vertical, 10)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(appState: appState, isPresented: $showingAppPicker)
        }
    }

    // MARK: - 底部按钮

    private func addFileOrFolder() {
        guard appState.settings.apps.count < 12 else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "添加"
        panel.message = "选择要添加到轮盘的文件或文件夹"
        if panel.runModal() == .OK, let url = panel.url {
            let item = AppItem(
                name: url.lastPathComponent,
                bundleIdentifier: "",
                path: url.path,
                itemType: .fileOrFolder
            )
            appState.settings.apps.append(item)
            IconCache.shared.invalidate()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: { showingAppPicker = true }) {
                Label("应用", systemImage: "plus")
            }
            .disabled(appState.settings.apps.count >= 12)

            Button(action: { addFileOrFolder() }) {
                Label("文件夹", systemImage: "folder.badge.plus")
            }
            .disabled(appState.settings.apps.count >= 12)

            Spacer()

            Text("\(appState.settings.apps.count) / 12")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.quaternary))

            Spacer()

            Button("恢复默认") {
                selectedIndex = nil
                appState.settings.apps = AppState.defaultApps()
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 圆环

    private var pieRing: some View {
        let dark = colorScheme == .dark
        let shadowColor: Color = .black.opacity(dark ? 0.4 : 0.08)
        let ringColor: Color = dark ? Color(red: 0.16, green: 0.17, blue: 0.21) : .white.opacity(0.75)
        let borderColor: Color = dark ? Color(red: 0.28, green: 0.30, blue: 0.35) : .white.opacity(0.5)
        let fillColor: Color = dark ? Color(red: 0.11, green: 0.12, blue: 0.15) : .white.opacity(0.55)
        let strokeColor: Color = dark ? Color(red: 0.22, green: 0.23, blue: 0.28) : .primary.opacity(0.06)

        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [shadowColor, .clear],
                                     center: .center, startRadius: outerRadius - 5, endRadius: outerRadius + 20))
                .frame(width: outerRadius * 2 + 40, height: outerRadius * 2 + 40)
            Circle().fill(ringColor).frame(width: outerRadius * 2, height: outerRadius * 2)
            Circle().stroke(borderColor, lineWidth: 0.5).frame(width: outerRadius * 2, height: outerRadius * 2)
            Circle().fill(fillColor).frame(width: innerRadius * 2, height: innerRadius * 2)
            Circle().stroke(strokeColor, lineWidth: 0.5).frame(width: innerRadius * 2, height: innerRadius * 2)
            centerLabel
        }
    }

    // MARK: - 中心标签

    @ViewBuilder
    private var centerLabel: some View {
        if let idx = selectedIndex, idx < appState.settings.apps.count {
            // 选中状态：显示名称 + 删除按钮
            VStack(spacing: 6) {
                Text(appState.settings.apps[idx].displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        let id = appState.settings.apps[idx].id
                        selectedIndex = nil
                        appState.settings.apps.removeAll { $0.id == id }
                    }
                }) {
                    Label("移除", systemImage: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else if draggingIndex != nil {
            Text("拖到目标位置松开")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        } else if appState.settings.apps.isEmpty {
            Text("点击下方添加应用")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            Text("点击选中 · 拖拽排序")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 图标

    // 拖拽时的预览顺序：模拟 item 已移动到目标位置
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
            // 非拖拽图标用预览位置，拖拽图标跟随鼠标
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

        // 拖拽中的图标跟鼠标，其他图标平滑移到预览位置
        let posX = isDragging ? originalPos.x + dragTranslation.width : targetPos.x
        let posY = isDragging ? originalPos.y + dragTranslation.height : targetPos.y

        return ZStack {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(isDragging ? 0.2 : 0.1),
                        radius: isDragging ? 4 : 1, x: 0, y: isDragging ? 2 : 0.5)
                .scaleEffect(isDragging ? 1.2 : (isSelected ? 1.15 : 1.0))

            if isSelected && !isDragging {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: iconSize + 6, height: iconSize + 6)
            }
        }
        .position(x: posX, y: posY)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: displaySlot)
        .zIndex(isDragging ? 10 : (isSelected ? 5 : 0))
        .gesture(dragGesture(index: index, total: total, originX: originalPos.x, originY: originalPos.y))
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedIndex = selectedIndex == index ? nil : index
            }
        }
    }

    // MARK: - 拖拽手势

    private func dragGesture(index: Int, total: Int, originX: CGFloat, originY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if draggingIndex == nil { selectedIndex = nil }
                draggingIndex = index
                dragTranslation = value.translation

                // 实时计算目标位置，让其他图标预览移动
                let absX = originX + value.translation.width
                let absY = originY + value.translation.height
                let target = slotIndex(at: CGPoint(x: absX, y: absY), total: total)
                if target != dragTargetIndex {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        dragTargetIndex = target
                    }
                }
            }
            .onEnded { value in
                let absX = originX + value.translation.width
                let absY = originY + value.translation.height
                let target = slotIndex(at: CGPoint(x: absX, y: absY), total: total)

                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    if target != index {
                        let item = appState.settings.apps.remove(at: index)
                        let insertAt = min(target, appState.settings.apps.count)
                        appState.settings.apps.insert(item, at: insertAt)
                    }
                    draggingIndex = nil
                    dragTranslation = .zero
                    dragTargetIndex = nil
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
                Text("添加应用")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("完成") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }

            TextField("搜索应用...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List(filteredApps) { app in
                HStack(spacing: 12) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)

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

                    Button(action: { addApp(app) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
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
        guard appState.settings.apps.count < 12 else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            appState.settings.apps.append(app)
        }
    }
}

// MARK: - 通用设置

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("快捷键") {
                HotkeyRecorderRow(appState: appState)
            }

            Section("交互模式") {
                Picker("模式", selection: $appState.settings.interactionMode) {
                    ForEach(InteractionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("轮盘位置") {
                Picker("位置", selection: $appState.settings.menuPosition) {
                    Text("跟随鼠标").tag(MenuPosition.followMouse)
                    Text("屏幕居中").tag(MenuPosition.screenCenter)
                }
                .pickerStyle(.radioGroup)
            }

            Section("外观") {
                Picker("主题", selection: $appState.settings.appearanceMode) {
                    Text("跟随系统").tag(AppearanceMode.system)
                    Text("浅色").tag(AppearanceMode.light)
                    Text("深色").tag(AppearanceMode.dark)
                }
                .onChange(of: appState.settings.appearanceMode) { _ in
                    NotificationCenter.default.post(name: .appearanceChanged, object: nil)
                }

                HStack {
                    Text("菜单半径")
                    Slider(value: $appState.settings.menuRadius, in: 100...180, step: 10)
                    Text("\(Int(appState.settings.menuRadius))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }

                HStack {
                    Text("图标大小")
                    Slider(value: $appState.settings.iconSize, in: 32...64, step: 4)
                    Text("\(Int(appState.settings.iconSize))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            Section("反馈") {
                Toggle("触觉反馈（触控板）", isOn: $appState.settings.hapticFeedback)
                Toggle("音效", isOn: $appState.settings.soundEffects)
            }

            Section("系统") {
                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .onAppear {
            launchAtLogin = getLaunchAtLogin()
        }
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
    let appState: AppState
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("快捷键")
            Spacer()

            if isRecording {
                Text("按下新快捷键…")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
            } else {
                Button(action: { startRecording() }) {
                    HStack(spacing: 2) {
                        ForEach(modifierSymbols, id: \.self) { sym in
                            KeyCap(sym)
                        }
                        KeyCap(HotkeyConfig.keyCodeToString(appState.settings.hotkey.keyCode))
                    }
                }
                .buttonStyle(.plain)
            }
        }
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
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // 需要至少一个修饰键
            guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
                if event.keyCode == 53 { // Escape 取消
                    stopRecording()
                }
                return nil
            }

            // 保存新快捷键
            appState.settings.hotkey = HotkeyConfig(keyCode: event.keyCode, modifiers: mods)
            stopRecording()

            // 通知 AppDelegate 重新注册
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
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
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.12), radius: 0.5, x: 0, y: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.separator, lineWidth: 0.5)
            )
    }
}

// MARK: - 关于页

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.58, blue: 1.0),
                                Color(red: 0.55, green: 0.36, blue: 0.95),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.25), radius: 12, x: 0, y: 4)

                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("饼状菜单")
                    .font(.system(size: 20, weight: .semibold))
                Text("PieMenu")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("版本 1.0.0")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .frame(width: 180)

            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "command", text: "按快捷键唤出饼状菜单")
                tipRow(icon: "cursorarrow.click", text: "点击图标启动或切换应用")
                tipRow(icon: "cursorarrow.click.2", text: "右键任意位置关闭菜单")
                tipRow(icon: "gearshape", text: "点击中心齿轮打开设置")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
                .frame(width: 18, alignment: .center)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 交互模式

extension InteractionMode {
    var displayName: String {
        switch self {
        case .hold: return "按住模式（按住快捷键，松开时选择）"
        case .click: return "点击模式（按快捷键弹出，鼠标点击选择）"
        }
    }
}
