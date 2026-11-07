#!/usr/bin/env python3
"""Build and run controller regressions outside the app's preferences domain."""

from pathlib import Path
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    binary = root / "build" / "camera-settings-regression"
    binary.parent.mkdir(parents=True, exist_ok=True)
    sources = sorted((root / "Shared").rglob("*.swift"))
    sources += sorted((root / "App" / "Camera").glob("*.swift"))
    sources += [root / "App" / "CameraModel.swift", root / "Tools" / "VerifyCameraSettings.swift"]
    subprocess.run(
        ["xcrun", "swiftc", "-O", "-swift-version", "6", "-parse-as-library",
         *map(str, sources), "-o", str(binary)],
        cwd=root, check=True, timeout=180,
    )
    subprocess.run([str(binary)], cwd=root, check=True, timeout=30)


if __name__ == "__main__":
    main()
