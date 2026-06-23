#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Sources" / "PieMenu" / "PieMenuApp.swift"
PROJECT_YML = ROOT / "project.yml"
PBXPROJ = ROOT / "Orbis.xcodeproj" / "project.pbxproj"
STORE_COPY = ROOT / "docs" / "appstore" / "store-copy.md"
PRIVACY = ROOT / "docs" / "appstore" / "privacy-policy.html"


def require(text: str, needle: str, reason: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {reason}: {needle}")


def forbid(text: str, needle: str, reason: str) -> None:
    if needle in text:
        raise AssertionError(f"Forbidden {reason}: {needle}")


def main() -> None:
    app = APP.read_text()
    project_yml = PROJECT_YML.read_text()
    pbxproj = PBXPROJ.read_text()
    store_copy = STORE_COPY.read_text()
    privacy = PRIVACY.read_text()

    app_requirements = [
        ('"显示 Arcly"', "menu show command uses the new app name"),
        ('alert.messageText = "欢迎使用 Arcly！"', "onboarding title uses the new app name"),
        ('"退出 Arcly"', "quit menu item uses the new app name"),
        ('accessibilityDescription: "Arcly"', "menu bar icon accessibility label uses the new app name"),
        ('button.toolTip = "Arcly"', "menu bar tooltip uses the new app name"),
        ('window.title = "Arcly 设置"', "settings window title uses the new app name"),
    ]
    for needle, reason in app_requirements:
        require(app, needle, reason)

    for old in [
        '"显示 Orbis"',
        '"欢迎使用 Orbis！"',
        '"退出 Orbis"',
        'accessibilityDescription: "Orbis"',
        'button.toolTip = "Orbis"',
        '"Orbis 设置"',
    ]:
        forbid(app, old, "old user-facing Orbis app string")

    project_requirements = [
        ("PRODUCT_NAME: Arcly", "generated project product name"),
        ("INFOPLIST_KEY_CFBundleDisplayName: Arcly", "generated project display name"),
        ('INFOPLIST_KEY_NSHumanReadableCopyright: "Copyright © 2025 Arcly. All rights reserved."', "generated project copyright"),
        ("PRODUCT_BUNDLE_IDENTIFIER: com.qingshan.orbis", "bundle identifier stays stable for App Store updates"),
    ]
    for needle, reason in project_requirements:
        require(project_yml, needle, reason)

    pbx_requirements = [
        ("PRODUCT_NAME = Arcly;", "Xcode project product name"),
        ("INFOPLIST_KEY_CFBundleDisplayName = Arcly;", "Xcode project display name"),
        ('INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2025 Arcly. All rights reserved.";', "Xcode project copyright"),
        ("PRODUCT_BUNDLE_IDENTIFIER = com.qingshan.orbis;", "Xcode bundle identifier stays stable"),
    ]
    for needle, reason in pbx_requirements:
        require(pbxproj, needle, reason)

    doc_requirements = [
        ("# Arcly", "App Store copy uses the new app name"),
        ("Arcly 不收集任何数据", "App Store privacy copy uses the new app name"),
        ("Privacy Policy for Arcly", "privacy policy heading uses the new app name"),
        ("Arcly does not collect", "privacy policy body uses the new app name"),
    ]
    combined_docs = store_copy + "\n" + privacy
    for needle, reason in doc_requirements:
        require(combined_docs, needle, reason)

    for old in [
        "# Orbis",
        "欢迎使用 Orbis",
        "退出 Orbis",
        "Orbis 不收集任何数据",
        "Privacy Policy for Orbis",
        "Orbis does not collect",
    ]:
        forbid(combined_docs, old, "old user-facing Orbis documentation string")

    print("Arcly rename contract passed.")


if __name__ == "__main__":
    main()
