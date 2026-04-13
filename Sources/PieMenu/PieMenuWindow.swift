import SwiftUI
import AppKit
import QuartzCore
import AVFoundation

// MARK: - 拖放目标视图

class DropTargetHostingView<Content: View>: NSHostingView<Content> {
    weak var pieWindow: PieMenuWindow?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        pieWindow?.handleDragUpdate(sender)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        pieWindow?.handleDragUpdate(sender)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        pieWindow?.appState.selectedIndex = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return pieWindow?.handleDrop(sender) ?? false
    }
}

// MARK: - PieMenuWindow

class PieMenuWindow: NSWindow {
    let appState: AppState
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var rightClickMonitor: Any?
    private var localRightClickMonitor: Any?
    private var escMonitor: Any?
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let windowSize: CGFloat = PieMenuView.windowSize

    // AVAudioPlayer 预缓冲，play() 近乎零延迟
    private static let tickPlayers: [AVAudioPlayer] = {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/Tink.aiff")
        return (0..<3).compactMap { _ in
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
            p.volume = 0.5
            p.prepareToPlay()  // 预填充音频缓冲区
            return p
        }
    }()
    private var tickIndex = 0

    init(appState: AppState) {
        self.appState = appState
        let size = PieMenuView.windowSize
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // screenSaver 级别确保在全屏 app 上也能显示
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.acceptsMouseMovedEvents = true

        let menuView = PieMenuView(appState: appState) { [weak self] app in
            self?.launchApp(app)
            self?.dismiss()
        }
        let hosting = DropTargetHostingView(rootView: menuView)
        hosting.pieWindow = self
        hosting.frame = NSRect(x: 0, y: 0, width: size, height: size)
        hosting.registerForDraggedTypes([.fileURL])
        self.contentView = hosting
        applyAppearance()
    }

    func showAt(point: NSPoint) {
        let anchor: NSPoint
        if appState.settings.menuPosition == .screenCenter,
           let screen = NSScreen.main {
            anchor = NSPoint(x: screen.frame.midX, y: screen.frame.midY)
        } else {
            anchor = point
        }

        var x = anchor.x - windowSize / 2
        var y = anchor.y - windowSize / 2

        // 限制在屏幕可见区域内
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main {
            let frame = screen.frame
            x = min(max(x, frame.minX), frame.maxX - windowSize)
            y = min(max(y, frame.minY), frame.maxY - windowSize)
        }

        self.setFrameOrigin(NSPoint(x: x, y: y))
        self.appState.selectedIndex = nil
        self.appState.isMenuVisible = true
        self.makeKeyAndOrderFront(nil)

        // Mouse movement - global
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateSelection()
        }
        // Mouse movement - local (when mouse is over our window)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateSelection()
            return event
        }

        // Click - global (clicking outside window)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
        // Click - local (clicking inside window)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self else { return nil }

            // 检查是否点击了中心区域（设置按钮）
            let mouseLocation = NSEvent.mouseLocation
            let center = NSPoint(x: self.frame.midX, y: self.frame.midY)
            let dx = mouseLocation.x - center.x
            let dy = mouseLocation.y - center.y
            let distance = sqrt(dx * dx + dy * dy)

            let innerRadius = self.appState.settings.menuRadius - 50
            if distance < innerRadius {
                // 点击中心 → 打开设置
                self.dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.onOpenSettings?()
                }
                return nil
            }

            // 点击应用图标 → 启动应用
            var appToLaunch: AppItem? = nil
            if let index = self.appState.selectedIndex, index < self.appState.settings.apps.count {
                appToLaunch = self.appState.settings.apps[index]
                if self.appState.settings.soundEffects {
                    NSSound(named: "Tink")?.play()
                }
            }
            self.dismiss()
            if let app = appToLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.launchApp(app)
                }
            }
            return nil
        }

        // 右键关闭 - global（窗口外右键）
        rightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
        // 右键关闭 - local（窗口内右键）
        localRightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            self?.dismiss()
            return nil
        }

        // Escape to close
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    func updateSelection() {
        let mouseLocation = NSEvent.mouseLocation
        let center = NSPoint(x: self.frame.midX, y: self.frame.midY)

        let dx = mouseLocation.x - center.x
        let dy = mouseLocation.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        let appCount = appState.settings.apps.count
        guard appCount > 0 else { return }

        let innerRadius = appState.settings.menuRadius - 50
        let outerRadius = appState.settings.menuRadius + 50

        let newIndex: Int?
        if distance < innerRadius || distance > outerRadius {
            newIndex = nil
        } else {
            var angle = atan2(dy, dx)
            if angle < 0 { angle += 2 * .pi }
            let sliceAngle = (2 * Double.pi) / Double(appCount)
            let adjustedAngle = fmod(angle + .pi / 2 + sliceAngle / 2, 2 * .pi)
            newIndex = Int(adjustedAngle / sliceAngle) % appCount
        }

        // 仅在值变化时更新，禁用 Core Animation 隐式动画防止闪烁
        if appState.selectedIndex != newIndex {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            appState.selectedIndex = newIndex
            CATransaction.commit()
            NSAnimationContext.endGrouping()

            if newIndex != nil {
                // 触觉 + 音效同步触发
                if appState.settings.hapticFeedback {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                if appState.settings.soundEffects && !Self.tickPlayers.isEmpty {
                    let p = Self.tickPlayers[tickIndex % Self.tickPlayers.count]
                    p.currentTime = 0
                    p.play()
                    tickIndex += 1
                }
            }
        }
    }

    // MARK: - 拖放处理

    func handleDragUpdate(_ sender: NSDraggingInfo) {
        // 将拖拽位置转换为屏幕坐标，复用 selection 逻辑
        let windowPoint = sender.draggingLocation
        let screenPoint = self.convertPoint(toScreen: windowPoint)
        let center = NSPoint(x: self.frame.midX, y: self.frame.midY)

        let dx = screenPoint.x - center.x
        let dy = screenPoint.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        let appCount = appState.settings.apps.count
        guard appCount > 0 else { return }

        let innerRadius = appState.settings.menuRadius - 50
        let outerRadius = appState.settings.menuRadius + 50

        let newIndex: Int?
        if distance < innerRadius || distance > outerRadius {
            newIndex = nil
        } else {
            var angle = atan2(dy, dx)
            if angle < 0 { angle += 2 * .pi }
            let sliceAngle = (2 * Double.pi) / Double(appCount)
            let adjustedAngle = fmod(angle + .pi / 2 + sliceAngle / 2, 2 * .pi)
            newIndex = Int(adjustedAngle / sliceAngle) % appCount
        }

        if appState.selectedIndex != newIndex {
            appState.selectedIndex = newIndex
            if newIndex != nil && appState.settings.hapticFeedback {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
    }

    func handleDrop(_ sender: NSDraggingInfo) -> Bool {
        guard let index = appState.selectedIndex,
              index < appState.settings.apps.count else {
            dismiss()
            return false
        }

        let app = appState.settings.apps[index]

        // 读取拖入的文件 URL
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty else {
            dismiss()
            return false
        }

        if appState.settings.soundEffects {
            NSSound(named: "Tink")?.play()
        }

        dismiss()

        // 用目标 app 打开文件
        if app.itemType == .app,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config) { _, error in
                if let error = error {
                    NSLog("❌ 拖放打开失败: %@", error.localizedDescription)
                } else {
                    NSLog("✅ 已用 %@ 打开 %d 个文件", app.name, urls.count)
                }
            }
        } else {
            // 文件夹类型：直接打开文件
            for url in urls {
                NSWorkspace.shared.open(url)
            }
        }

        return true
    }

    func applyAppearance() {
        switch appState.settings.appearanceMode {
        case .light: self.appearance = NSAppearance(named: .aqua)
        case .dark: self.appearance = NSAppearance(named: .darkAqua)
        case .system: self.appearance = nil
        }
    }

    func activateSelected() {
        guard let index = appState.selectedIndex,
              index < appState.settings.apps.count else { return }
        let app = appState.settings.apps[index]
        launchApp(app)
    }

    func launchApp(_ app: AppItem) {
        if app.itemType == .fileOrFolder {
            NSLog("📂 Opening: %@", app.path)
            NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
            return
        }

        NSLog("🚀 Launching: %@ (%@)", app.name, app.bundleIdentifier)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                if let error = error {
                    NSLog("  ❌ 启动失败: %@", error.localizedDescription)
                } else {
                    NSLog("  ✅ 已切换到: %@", app.name)
                }
            }
        } else {
            NSLog("  ❌ 找不到应用: %@", app.bundleIdentifier)
        }
    }

    func dismiss() {
        appState.selectedIndex = nil
        removeMonitors()

        // 触发关闭动画
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            appState.isMenuVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.orderOut(nil)
            self?.onDismiss?()
        }
    }

    private func removeMonitors() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m); localMouseMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = localClickMonitor { NSEvent.removeMonitor(m); localClickMonitor = nil }
        if let m = rightClickMonitor { NSEvent.removeMonitor(m); rightClickMonitor = nil }
        if let m = localRightClickMonitor { NSEvent.removeMonitor(m); localRightClickMonitor = nil }
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
    }

    override func close() {
        dismiss()
    }

    deinit {
        removeMonitors()
    }
}
