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

    queue_guard = """if refreshInFlight {
            refreshQueuedAfterInFlight = true
            return
        }"""
    assert queue_guard in body, "refreshNowPlaying should queue follow-up reads while one read is already running"

    guard_index = body.find(queue_guard)
    terminate_index = body.find("refreshProcess?.terminate()")
    if terminate_index != -1:
        assert guard_index < terminate_index, "in-flight queue guard must run before any helper process termination"

    assert "refreshQueuedAfterInFlight = false" in body, "new helper read should reset queued refresh state only after it starts"

    print("Now-playing refresh queue contract passed.")


if __name__ == "__main__":
    main()
