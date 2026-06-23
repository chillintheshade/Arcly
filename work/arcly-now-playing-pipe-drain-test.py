#!/usr/bin/env python3
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources" / "Arcly" / "NowPlayingService.swift"


def main() -> None:
    source = SOURCE.read_text()
    match = re.search(
        r"private func refreshNowPlaying\(\) \{(?P<body>.*?)\n    \}\n\n    private func completeRefresh",
        source,
        re.S,
    )
    assert match, "refreshNowPlaying body not found"
    body = match.group("body")

    assert "readabilityHandler" in body, (
        "helper stdout must be drained while the process is running; large artwork "
        "can otherwise fill the pipe and force the refresh timeout"
    )
    assert "availableData" in body, "stdout draining should append chunks from availableData"
    assert "let data = output.fileHandleForReading.readDataToEndOfFile()" not in body, (
        "do not wait until process termination to read all stdout; that can deadlock on large artwork"
    )

    print("Now-playing pipe drain contract passed.")


if __name__ == "__main__":
    main()
