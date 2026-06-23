#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_STATE = ROOT / "Sources" / "Arcly" / "AppState.swift"
PIE_VIEW = ROOT / "Sources" / "Arcly" / "ArclyWheelView.swift"
SETTINGS_VIEW = ROOT / "Sources" / "Arcly" / "SettingsView.swift"


def require(source: str, needle: str, reason: str) -> None:
    if needle not in source:
        raise AssertionError(f"Missing {reason}: {needle}")


def forbid(source: str, needle: str, reason: str) -> None:
    if needle in source:
        raise AssertionError(f"Forbidden {reason}: {needle}")


def main() -> None:
    app_state = APP_STATE.read_text()
    pie_view = PIE_VIEW.read_text()
    settings_view = SETTINGS_VIEW.read_text()

    app_state_requirements = [
        ("var menuOpacity: Double = 1.0", "default menu glass opacity"),
        ("menuOpacity = (try? c.decode(Double.self, forKey: .menuOpacity)) ?? 1.0", "opacity decoder fallback"),
    ]
    for needle, reason in app_state_requirements:
        require(app_state, needle, reason)

    pie_requirements = [
        ("private var menuGlassOpacity: Double", "clamped menu glass opacity accessor"),
        ("private var glassSurfaceFillOpacity: Double", "visible opacity-mapped glass surface"),
        ("appState.settings.menuOpacity", "radial menu reads saved opacity"),
        ("glassSurfaceLayer", "radial menu renders a visible opacity surface"),
        ("glassRefractionLayer", "static glass refraction overlay"),
        (".opacity(menuGlassOpacity)", "opacity affects glass layers"),
    ]
    for needle, reason in pie_requirements:
        require(pie_view, needle, reason)

    settings_requirements = [
        ('title: Loc.string("settings.opacity")', "opacity slider label"),
        ("value: $appState.settings.menuOpacity", "opacity slider binding"),
        ("range: 0.15...1.0", "opacity slider range with visible low end"),
        ("step: 0.05", "opacity slider step"),
        ("appState.settings.menuOpacity", "settings preview reads opacity"),
        ("private var glassSurfaceFillOpacity: Double", "settings preview visible opacity surface"),
        ("settingsGlassSurfaceLayer", "settings preview renders opacity surface"),
        ("settingsGlassRefractionLayer", "settings preview refraction overlay"),
    ]
    for needle, reason in settings_requirements:
        require(settings_view, needle, reason)

    forbid(app_state, "glassRefractionEnabled", "persisted glass refraction toggle")
    forbid(pie_view, "glassRefractionEnabled", "runtime glass refraction toggle")
    forbid(settings_view, "glassRefractionEnabled", "settings glass refraction toggle")
    forbid(settings_view, "玻璃折射", "user-facing glass refraction control")
    forbid(settings_view, "折射强度", "user-facing refraction strength control")
    forbid(settings_view, "refractionStrength", "hidden adjustable refraction strength setting")
    forbid(app_state, "refractionStrength", "persisted adjustable refraction strength setting")
    forbid(pie_view, "refractionStrength", "runtime adjustable refraction strength setting")

    print("Glass appearance contract passed.")


if __name__ == "__main__":
    main()
