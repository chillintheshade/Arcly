import SwiftUI
import AppKit
import Carbon

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("PieMenu.hotkeyChanged")
    static let appearanceChanged = Notification.Name("PieMenu.appearanceChanged")
}

// MARK: - Data Models

enum PieItemType: String, Codable {
    case app = "app"
    case fileOrFolder = "fileOrFolder"
}

struct AppItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var bundleIdentifier: String
    var path: String
    var itemType: PieItemType = .app

    /// 缓存版本 — 视图中使用这两个
    var displayName: String { IconCache.shared.displayName(for: self) }
    var icon: NSImage { IconCache.shared.icon(for: self) }

    /// 实际加载逻辑（仅由 IconCache 调用一次）
    func resolveDisplayName() -> String {
        if itemType == .fileOrFolder {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        if let cn = AppItem.chineseNames[bundleIdentifier] { return cn }
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.localizedNameKey]),
           let localized = values.localizedName {
            let cleaned = localized.replacingOccurrences(of: ".app", with: "")
            if cleaned != name && !cleaned.isEmpty { return cleaned }
        }
        if let bundle = Bundle(url: url) {
            if let dn = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String { return dn }
            if let bn = bundle.localizedInfoDictionary?["CFBundleName"] as? String { return bn }
        }
        return name
    }

    func loadIcon() -> NSImage {
        if itemType == .fileOrFolder {
            return NSWorkspace.shared.icon(forFile: path)
        }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: app.path)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    var isRunning: Bool {
        guard itemType == .app else { return false }
        return !NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleIdentifier }.isEmpty
    }

    /// 常用 app 中文名映射（系统 API 可能拿不到中文名时的兜底）
    static let chineseNames: [String: String] = [
        // Apple 系统应用
        "com.apple.finder": "访达",
        "com.apple.Safari": "Safari 浏览器",
        "com.apple.MobileSMS": "信息",
        "com.apple.mail": "邮件",
        "com.apple.iCal": "日历",
        "com.apple.Notes": "备忘录",
        "com.apple.Music": "音乐",
        "com.apple.systempreferences": "系统设置",
        "com.apple.Photos": "照片",
        "com.apple.reminders": "提醒事项",
        "com.apple.Maps": "地图",
        "com.apple.weather": "天气",
        "com.apple.news": "新闻",
        "com.apple.stocks": "股市",
        "com.apple.Home": "家庭",
        "com.apple.freeform": "无边记",
        "com.apple.dt.Xcode": "Xcode",
        "com.apple.Terminal": "终端",
        "com.apple.ActivityMonitor": "活动监视器",
        "com.apple.Preview": "预览",
        "com.apple.TextEdit": "文本编辑",
        "com.apple.AppStore": "App Store",
        "com.apple.FaceTime": "FaceTime 通话",
        "com.apple.calculator": "计算器",
        "com.apple.AddressBook": "通讯录",
        "com.apple.TV": "Apple TV",
        "com.apple.podcasts": "播客",
        "com.apple.Books": "图书",
        "com.apple.Passwords": "密码",
        "com.apple.ScreenSharing": "屏幕共享",
        "com.apple.Dictionary": "词典",
        "com.apple.shortcuts": "快捷指令",
        "com.apple.Automator": "自动操作",
        "com.apple.ColorSyncUtility": "ColorSync 实用工具",
        "com.apple.Console": "控制台",
        "com.apple.DiskUtility": "磁盘工具",
        "com.apple.FontBook": "字体册",
        "com.apple.GarageBand": "库乐队",
        "com.apple.iMovie": "iMovie 剪辑",
        "com.apple.iWork.Keynote": "Keynote 讲演",
        "com.apple.iWork.Numbers": "Numbers 表格",
        "com.apple.iWork.Pages": "Pages 文稿",
        "com.apple.keychainaccess": "钥匙串访问",
        "com.apple.ScriptEditor2": "脚本编辑器",
        "com.apple.ScreenCaptureUI": "截屏",
        "com.apple.VoiceMemos": "语音备忘录",
        "com.apple.Chess": "国际象棋",
        "com.apple.PhotoBooth": "Photo Booth",
        "com.apple.QuickTimePlayerX": "QuickTime Player",
        "com.apple.Stickies": "便签",
        "com.apple.siri.launcher": "Siri",
        "com.apple.MigrateAssistant": "迁移助理",
        "com.apple.BluetoothFileExchange": "蓝牙文件交换",
        "com.apple.audio.AudioMIDISetup": "音频 MIDI 设置",
        "com.apple.SystemProfiler": "系统信息",
        "com.apple.grapher": "Grapher",
        "com.apple.DigitalColorMeter": "数码测色计",
        "com.apple.airport.airportutility": "AirPort 实用工具",
        "com.apple.Accessibility.AccessibilityVisualsPreferences": "辅助功能",
        // 常用第三方应用
        "com.tencent.xinWeChat": "微信",
        "com.tencent.qq": "QQ",
        "com.tencent.QQMusicMac": "QQ音乐",
        "com.tencent.meeting": "腾讯会议",
        "com.tencent.LemonMonitor": "腾讯柠檬清理",
        "com.tencent.WeWorkMac": "企业微信",
        "com.alibaba.DingTalkMac": "钉钉",
        "com.netease.163music": "网易云音乐",
        "com.baidu.BaiduNetdisk-mac": "百度网盘",
        "com.feishu.Lark": "飞书",
        "com.bytedance.macos.feishu": "飞书",
        "com.electron.lark": "飞书",
        "com.wps.officemac": "WPS Office",
        "com.kingsoft.wpsoffice.mac": "WPS Office",
        "com.readdle.PDFExpert-Mac": "PDF Expert",
        "com.microsoft.Word": "Word",
        "com.microsoft.Excel": "Excel",
        "com.microsoft.Powerpoint": "PowerPoint",
        "com.microsoft.Outlook": "Outlook",
        "com.microsoft.onenote.mac": "OneNote",
        "com.microsoft.teams2": "Teams",
        "com.microsoft.VSCode": "VS Code",
        "com.microsoft.edgemac": "Edge",
        "com.google.Chrome": "Chrome",
        "org.mozilla.firefox": "Firefox",
        "com.brave.Browser": "Brave",
        "com.operasoftware.Opera": "Opera",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "com.spotify.client": "Spotify",
        "com.notion.id": "Notion",
        "us.zoom.xos": "Zoom",
        "com.figma.Desktop": "Figma",
        "com.obsproject.obs-studio": "OBS",
        "com.postmanlabs.mac": "Postman",
        "com.docker.docker": "Docker Desktop",
        "com.sublimetext.4": "Sublime Text",
        "com.jetbrains.intellij": "IntelliJ IDEA",
        "com.jetbrains.WebStorm": "WebStorm",
        "com.jetbrains.pycharm": "PyCharm",
        "com.jetbrains.goland": "GoLand",
        "com.jetbrains.CLion": "CLion",
        "com.jetbrains.datagrip": "DataGrip",
        "com.apple.iBooksAuthor": "iBooks Author",
        "com.raycast.macos": "Raycast",
        "com.alfredapp.Alfred": "Alfred",
        "com.crowdcafe.windowmagnet": "Magnet",
        "com.hegenberg.BetterTouchTool": "BetterTouchTool",
        "com.1password.1password": "1Password",
        "com.bitwarden.desktop": "Bitwarden",
        "com.nssurge.surge-mac": "Surge",
        "com.lemonjarLLC.clashX": "ClashX",
        "com.west2online.ClashXPro": "ClashX Pro",
        "com.v2rayu.V2rayU": "V2rayU",
        "net.shadowsocks.ShadowsocksX-NG": "ShadowsocksX-NG",
        "com.sequelpro.SequelPro": "Sequel Pro",
        "com.tinyapp.TablePlus": "TablePlus",
        "com.ToothFairy.macOS": "ToothFairy",
        "me.sketch.Sketch": "Sketch",
        "com.pixelmatorteam.pixelmator.x": "Pixelmator Pro",
        "com.colliderli.iStatMenus": "iStat Menus",
        "com.agilebits.onepassword7": "1Password 7",
        "com.toggl.daneel": "Toggl Track",
        "com.tencent.wechatdevtools": "微信开发者工具",
    ]
}

enum InteractionMode: String, Codable, CaseIterable {
    case hold = "hold"
    case click = "click"
}

enum MenuPosition: String, Codable, CaseIterable {
    case followMouse = "followMouse"
    case screenCenter = "screenCenter"
}

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}

struct HotkeyConfig: Codable {
    var keyCode: UInt16 = 2 // D key
    var modifiers: NSEvent.ModifierFlags = [.command, .shift]

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyCodeToString(keyCode))
        return parts.joined()
    }

    /// 转换为 Carbon API 的修饰键
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    static func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete",
            53: "Esc", 0: "A", 1: "S", 2: "D", 3: "F",
            4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I",
            35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'",
            41: ";", 42: "\\", 43: ",", 44: "/", 47: ".",
            50: "`", 76: "Enter",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    // Codable conformance for NSEvent.ModifierFlags
    enum CodingKeys: String, CodingKey {
        case keyCode, rawModifiers
    }

    init(keyCode: UInt16 = 2, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawModifiers = try container.decode(UInt.self, forKey: .rawModifiers)
        modifiers = NSEvent.ModifierFlags(rawValue: rawModifiers)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .rawModifiers)
    }
}

struct AppSettings: Codable {
    var apps: [AppItem] = []
    var interactionMode: InteractionMode = .click
    var hotkey: HotkeyConfig = HotkeyConfig()
    var menuRadius: Double = 140
    var iconSize: Double = 48
    var menuPosition: MenuPosition = .followMouse
    var appearanceMode: AppearanceMode = .system
    var hapticFeedback: Bool = true
    var soundEffects: Bool = true
    var hasCompletedOnboarding: Bool = false
}

// MARK: - Icon Cache

final class IconCache {
    static let shared = IconCache()
    private var cache: [String: NSImage] = [:]
    private var nameCache: [String: String] = [:]

    func icon(for app: AppItem) -> NSImage {
        if let img = cache[app.bundleIdentifier] { return img }
        let img = app.loadIcon()
        cache[app.bundleIdentifier] = img
        return img
    }

    func displayName(for app: AppItem) -> String {
        if let name = nameCache[app.bundleIdentifier] { return name }
        let name = app.resolveDisplayName()
        nameCache[app.bundleIdentifier] = name
        return name
    }

    func invalidate() {
        cache.removeAll()
        nameCache.removeAll()
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet { saveSettings() }
    }
    @Published var selectedIndex: Int? = nil
    @Published var isMenuVisible: Bool = false

    private let settingsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PieMenu")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }()

    init() {
        if let data = try? Data(contentsOf: settingsURL),
           var decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            // 迁移：修复旧版保存的无效快捷键（⌥Space）
            if decoded.hotkey.keyCode == 49 && decoded.hotkey.modifiers == .option {
                decoded.hotkey = HotkeyConfig() // 重置为默认 ⌘⇧D
            }
            self.settings = decoded
        } else {
            self.settings = AppSettings()
            // Add some default apps
            self.settings.apps = Self.defaultApps()
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL)
        }
    }

    static func defaultApps() -> [AppItem] {
        let defaultBundleIDs = [
            "com.apple.finder",
            "com.apple.Safari",
            "com.apple.MobileSMS",
            "com.apple.mail",
            "com.apple.iCal",
            "com.apple.Notes",
            "com.apple.Music",
            "com.apple.systempreferences",
        ]

        return defaultBundleIDs.compactMap { bundleID in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
            let localizedName = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            return AppItem(name: localizedName, bundleIdentifier: bundleID, path: url.path)
        }
    }

    // 获取已安装的用户可见应用
    static func installedApps() -> [AppItem] {
        var apps: [AppItem] = []
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
        ]

        // 过滤掉后台服务和系统工具（关键字匹配）
        let hiddenKeywords = [
            "Agent", "Stub", "Diagnostics", "Utility",
            "Helper", "Daemon", "Installer", "Migration",
            "Setup", "Updater", "Reporter", "PrefPane",
            "UIAgent", "Service", "ScreenSaver",
            "WidgetKit", "Widget", "WindowManager",
            "Education", "ShowDesktop",
            "VoiceOver", "Wallpaper",
            "CoreLocationAgent", "CoreServicesUIAgent",
            "PrintCenter", "HelpViewer", "FileMerge",
            "CrashReporter", "Problem", "Feedback",
            "AXVisualSupportAgent", "LocationMenu",
            "UniversalControl", "WiFiAgent",
            "Bluetooth", "CoreServices",
            "SpeakableItems", "AssistiveControl",
        ]

        // 精确匹配要隐藏的 bundle ID
        let hiddenBundleIDs: Set<String> = [
            "com.apple.VoiceOverUtility",
            "com.apple.SystemProfiler",
            "com.apple.ScreenSharing",
            "com.apple.DirectoryUtility",
            "com.apple.NetworkUtility",
            "com.apple.AVB-Audio-Configuration",
            "com.apple.MIDI-Configuration",
            "com.apple.wifi.diagnostics",
            "com.apple.BluetoothFileExchange",
            "com.apple.PacketLogger",
            "com.apple.FileSyncAgent",
            "com.apple.Ticket-Viewer",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow",
            "com.apple.notificationcenterui",
            "com.apple.controlcenter",
            "com.apple.dock",
            "com.apple.inputmethod.ChinaHandwriting",
            "com.apple.WatchFaceAlbums",
        ]

        // 精确匹配要隐藏的 app 名称
        let hiddenNames: Set<String> = [
            "VoiceOver",
            "Wallpaper",
            "Watch Face Help",
            "WindowManager",
            "WindowManagerShowDesktopEducation",
            "WidgetKit Simulator",
            "CoreLocationAgent",
            "HelpViewer",
            "CoreServicesUIAgent",
            "FileMerge",
            "Print Center",
        ]

        for searchPath in searchPaths {
            let url = URL(fileURLWithPath: searchPath)
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for fileURL in contents where fileURL.pathExtension == "app" {
                    if let bundle = Bundle(url: fileURL),
                       let bundleID = bundle.bundleIdentifier {
                        let rawName = FileManager.default.displayName(atPath: fileURL.path)
                            .replacingOccurrences(of: ".app", with: "")

                        // 精确名称匹配跳过
                        if hiddenNames.contains(rawName) { continue }

                        // bundle ID 匹配跳过
                        if hiddenBundleIDs.contains(bundleID) { continue }

                        // 关键字匹配跳过后台服务
                        let shouldHide = hiddenKeywords.contains { rawName.contains($0) }
                        if shouldHide { continue }

                        apps.append(AppItem(
                            name: rawName,
                            bundleIdentifier: bundleID,
                            path: fileURL.path
                        ))
                    }
                }
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
