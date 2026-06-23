#!/usr/bin/env python3
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "PieMenu" / "NowPlayingService.swift"


def main() -> None:
    source = SOURCE.read_text()
    match = re.search(
        r"private func refreshNowPlaying\(\) \{(?P<body>.*?)\n    \}\n\n    private func completeRefresh",
        source,
        re.S,
    )
    assert match, "refreshNowPlaying body not found"
    body = match.group("body")

    assert "guard let expectedBID = expectedBID else" not in body, (
        "refresh should not clear before asking MediaRemote; sandboxed builds may fail "
        "to enumerate the running player even when MediaRemote has current music"
    )
    assert "let expectedBID = musicApp?.bundleIdentifier" in body, (
        "running player identity should remain an optional validation hint, not a hard gate"
    )

    assert "private func completeRefresh(_ snapshot: NowPlayingSnapshot?, expectedBID: String?, refreshID: Int)" in source, (
        "expectedBID should be optional through completion"
    )
    assert "private func applyNowPlaying(_ snapshot: NowPlayingSnapshot, expectedBID: String?)" in source, (
        "expectedBID should be optional through apply"
    )

    print("Now-playing no running-app gate contract passed.")


if __name__ == "__main__":
    main()
