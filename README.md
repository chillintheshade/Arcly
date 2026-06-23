# Arcly

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="132" alt="Arcly app icon">
</p>

<p align="center">
  <strong>A liquid-glass command wheel for macOS.</strong><br>
  Launch apps, files, folders, and media controls without leaving your cursor.
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/platform-macOS-lightgrey">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange">
  <img alt="License" src="https://img.shields.io/badge/license-TBD-lightgrey">
</p>

Arcly is a lightweight radial launcher for macOS. Press a shortcut or use a mouse trigger, and a quiet circular menu appears where you are working. It is built for the small actions you repeat all day: opening apps, jumping into folders, controlling music, and keeping your hands in flow.

中文简介：Arcly 是一个 macOS 液态玻璃轮盘启动器，把常用应用、文件夹和音乐控制放到鼠标附近。

## Preview

<p align="center">
  <img src="docs/appstore/screenshots-raw/01-pie-menu.png" width="720" alt="Arcly radial launcher preview">
</p>

## Highlights

- Liquid-glass radial menu that stays visually light on top of your desktop
- App, file, and folder launch slots arranged around a wheel
- Music display and playback controls inside the center area
- Hotkey and mouse-trigger launch modes
- Adjustable wheel radius, icon size, opacity, theme, and menu position
- Native macOS app built with Swift and SwiftUI

## Why It Exists

Most launchers make you leave the place where you are already working. Arcly keeps the command surface under the cursor, so launching something feels closer to a gesture than a search.

## Build From Source

```bash
xcodebuild -project Orbis.xcodeproj -scheme Orbis -configuration Release build
```

The Xcode project and some internal identifiers still use `Orbis` / `com.qingshan.orbis` to preserve update and in-app purchase compatibility. The user-facing app name is `Arcly`.

## Notes

- Self-distributed local builds should be signed without the App Sandbox entitlement if MediaRemote music metadata is required.
- App Store distribution should keep the normal App Store signing and sandbox flow.
- This repository is still being cleaned up after the rename from Orbis to Arcly.

## Support

If Arcly matches the way you like to work on macOS, starring the repo helps more people find it.
