#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "PieMenu" / "NowPlayingService.swift"


def main() -> None:
    source = SOURCE.read_text()

    assert "private var emptyRefreshCount = 0" in source, (
        "NowPlayingService should count consecutive empty MediaRemote reads"
    )
    assert "private let maxEmptyRefreshesBeforeClear" in source, (
        "empty reads should be tolerated for a bounded number of refreshes"
    )
    assert "private func handleEmptyNowPlaying()" in source, (
        "empty reads should be handled separately from hard clearing"
    )
    assert "runningMusicApp != nil" in source[source.find("private func handleEmptyNowPlaying()"):], (
        "empty reads should retain the previous track while a music app is still running"
    )
    assert "trackName.isEmpty" in source[source.find("private func handleEmptyNowPlaying()"):], (
        "retention should only keep meaningful previous music metadata"
    )
    assert "emptyRefreshCount = 0" in source[source.find("private func applyNowPlaying"):], (
        "successful reads should reset the empty-read counter"
    )
    assert "handleEmptyNowPlaying()" in source[source.find("private func completeRefresh"):], (
        "nil helper/direct results should use stale retention instead of immediate clearing"
    )

    print("Now-playing stale retention contract passed.")


if __name__ == "__main__":
    main()
