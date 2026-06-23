#!/usr/bin/env python3
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "PieMenu" / "NowPlayingService.swift"


def main() -> None:
    source = SOURCE.read_text()
    assert "readNowPlayingDirect" in source, "NowPlayingService should have an in-process MediaRemote reader"

    match = re.search(
        r"private func refreshNowPlaying\(\) \{(?P<body>.*?)\n    \}\n\n    private func scheduleRefreshTimeout",
        source,
        re.S,
    )
    assert match, "refreshNowPlaying body not found"
    body = match.group("body")

    direct_index = body.find("Self.readNowPlayingDirect")
    helper_index = body.find("startHelperRefresh")
    assert direct_index != -1, "refreshNowPlaying should start with direct MediaRemote reads"
    assert helper_index != -1, "helper fallback should still be called"
    assert direct_index < helper_index, "direct MediaRemote read should run before helper fallback"
    assert "!snapshot.title.isEmpty" in body, "direct reads should only complete when they include track metadata"
    assert "self.startHelperRefresh(expectedBID: expectedBID, refreshID: refreshID)" in body, (
        "direct reads without metadata should fall back to the helper reader"
    )

    assert "Process()" in source, "helper fallback should remain available"
    assert "🎵" not in source, "temporary diagnostic music logs should not ship"

    print("Now-playing direct primary contract passed.")


if __name__ == "__main__":
    main()
