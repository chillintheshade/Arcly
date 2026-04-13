import AppKit
import SwiftUI
import Carbon
import ServiceManagement

@main
enum PieMenuEntry {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var appState = AppState()
    var pieWindow: PieMenuWindow?
    var settingsWindow: NSWindow?
    var hotKeyRef: EventHotKeyRef?
    var isMenuOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerHotKey()

        // 监听快捷键修改
        NotificationCenter.default.addObserver(
            self, selector: #selector(hotkeyDidChange),
            name: .hotkeyChanged, object: nil
        )

        // 监听外观修改
        NotificationCenter.default.addObserver(
            self, selector: #selector(appearanceDidChange),
            name: .appearanceChanged, object: nil
        )

        NSLog("✅ 饼状菜单已启动！按 %@ 打开菜单", appState.settings.hotkey.displayString)

        // 首次启动引导
        if !appState.settings.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showOnboarding()
            }
        }
    }

    func showOnboarding() {
        let alert = NSAlert()
        alert.messageText = "欢迎使用饼状菜单！"
        alert.informativeText = """
        快速上手：
        1. 按 \(appState.settings.hotkey.displayString) 唤出轮盘菜单
        2. 移动鼠标到目标应用，点击或松开即可启动
        3. 右键任意位置关闭菜单
        4. 点击菜单栏 ⊚ 图标打开设置

        提示：需要授权「辅助功能」权限才能使用全局快捷键。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "开始使用")
        alert.addButton(withTitle: "打开辅助功能设置")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // 打开辅助功能设置
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }

        appState.settings.hasCompletedOnboarding = true
    }

    @objc func appearanceDidChange() {
        pieWindow?.applyAppearance()
        applySettingsAppearance()
    }

    @objc func hotkeyDidChange() {
        registerHotKey()
        // 更新菜单栏显示
        if let menu = statusItem.menu,
           let showItem = menu.items.first {
            showItem.title = "显示饼状菜单  \(appState.settings.hotkey.displayString)"
        }
    }

    // 点 Dock 图标时弹饼状菜单
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showPieMenu()
        }
        return false
    }

    // MARK: - Dock 菜单（右键 Dock 图标）

    // Dock 右键菜单
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let dockMenu = NSMenu()

        let showItem = NSMenuItem(title: "显示饼状菜单", action: #selector(manualShowPieMenu), keyEquivalent: "")
        showItem.target = self
        dockMenu.addItem(showItem)

        dockMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        dockMenu.addItem(settingsItem)

        return dockMenu
    }

    // MARK: - 菜单栏图标

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⊚"
            button.toolTip = "饼状菜单"
            NSLog("✅ 状态栏图标已创建: title=%@", button.title)
        } else {
            NSLog("❌ 状态栏按钮创建失败")
        }

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "显示饼状菜单  \(appState.settings.hotkey.displayString)", action: #selector(manualShowPieMenu), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出饼状菜单", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - 全局快捷键

    private var eventHandlerInstalled = false

    func registerHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        let hotkey = appState.settings.hotkey
        let hotkeyKeyCode: UInt32 = UInt32(hotkey.keyCode)
        let carbonModifiers: UInt32 = hotkey.carbonModifiers

        let hotKeyID = EventHotKeyID(signature: OSType(0x50494531), id: 1)

        if !eventHandlerInstalled {
            var eventTypes = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                              eventKind: UInt32(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                              eventKind: UInt32(kEventHotKeyReleased)),
            ]

            let selfPtr = Unmanaged.passUnretained(self).toOpaque()

            InstallEventHandler(
                GetApplicationEventTarget(),
                { (_, event, userData) -> OSStatus in
                    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                    let eventKind = GetEventKind(event)
                    DispatchQueue.main.async {
                        if eventKind == UInt32(kEventHotKeyPressed) {
                            delegate.handleHotKeyDown()
                        } else if eventKind == UInt32(kEventHotKeyReleased) {
                            delegate.handleHotKeyUp()
                        }
                    }
                    return noErr
                },
                2,
                &eventTypes,
                selfPtr,
                nil
            )
            eventHandlerInstalled = true
        }

        let status = RegisterEventHotKey(
            hotkeyKeyCode, carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )

        if status == noErr {
            NSLog("✅ 快捷键注册成功: %@", hotkey.displayString)
        } else {
            NSLog("❌ 快捷键注册失败: %d", status)
        }
    }

    // MARK: - 快捷键事件

    func handleHotKeyDown() {
        NSLog("🔑 handleHotKeyDown: mode=%@, isMenuOpen=%d", appState.settings.interactionMode.rawValue, isMenuOpen)
        if appState.settings.interactionMode == .hold {
            // 按住模式：按下 → 显示菜单
            if !isMenuOpen {
                showPieMenu()
            }
        } else {
            // 点击模式：按下 → 切换菜单
            togglePieMenu()
        }
    }

    func handleHotKeyUp() {
        if appState.settings.interactionMode == .hold && isMenuOpen {
            // 按住模式：松开 → 执行选中并关闭
            if let index = appState.selectedIndex,
               index < appState.settings.apps.count {
                let app = appState.settings.apps[index]
                closePieMenu()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.pieWindow?.launchApp(app) ?? {
                        // pieWindow 已关闭，直接启动
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
                            let config = NSWorkspace.OpenConfiguration()
                            config.activates = true
                            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
                        }
                    }()
                }
            } else {
                closePieMenu()
            }
        }
    }

    // MARK: - 饼状菜单操作

    func togglePieMenu() {
        if isMenuOpen {
            closePieMenu()
        } else {
            showPieMenu()
        }
    }

    func showPieMenu() {
        // 清理旧窗口，先置空 onDismiss 防止延迟回调覆盖新窗口
        if let old = pieWindow {
            old.onDismiss = nil
            old.dismiss()
        }
        pieWindow = nil
        isMenuOpen = false

        let window = PieMenuWindow(appState: appState)
        window.onDismiss = { [weak self, weak window] in
            // 仅当仍是当前窗口时才清理
            guard let self = self, self.pieWindow === window else { return }
            self.pieWindow = nil
            self.isMenuOpen = false
        }
        window.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        pieWindow = window
        let mouseLocation = NSEvent.mouseLocation
        window.showAt(point: mouseLocation)
        isMenuOpen = true
        NSLog("✅ showPieMenu: window shown at (%.0f, %.0f)", mouseLocation.x, mouseLocation.y)
    }

    func closePieMenu() {
        pieWindow?.onDismiss = nil  // 防止延迟回调干扰
        pieWindow?.dismiss()
        pieWindow = nil
        isMenuOpen = false
    }

    @objc func manualShowPieMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.showPieMenu()
        }
    }

    @objc func openSettings() {
        NSApp.setActivationPolicy(.regular)
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(appState)
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "饼状菜单 - 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 520, height: 540))
            window.center()
            window.delegate = self
            self.settingsWindow = window
        }
        applySettingsAppearance()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applySettingsAppearance() {
        switch appState.settings.appearanceMode {
        case .light: settingsWindow?.appearance = NSAppearance(named: .aqua)
        case .dark: settingsWindow?.appearance = NSAppearance(named: .darkAqua)
        case .system: settingsWindow?.appearance = nil
        }
    }

    // 设置窗口关闭时隐藏 Dock
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
