"""Map a release tag to Apple's numeric marketing version and a growing CI build."""
import os
import re
from pathlib import Path


def release_version(tag, run_number, project):
    match = re.fullmatch(r"v?(\d+\.\d+\.\d+)(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?", tag)
    if not match:
        raise ValueError("Release tag must be vX.Y.Z, optionally with a prerelease suffix")
    base = re.search(r"CURRENT_PROJECT_VERSION:\s*['\"]?(\d+)", project)
    if not base or not run_number.isdecimal() or int(run_number) < 1:
        raise ValueError("Invalid project build number or GitHub run number")
    build = int(base[1]) + int(run_number)
    if build > 9999:
        raise ValueError("CI build exceeds Apple's four-digit major version limit")
    return match[1], str(build)


if __name__ == "__main__":
    tag = os.environ["RELEASE_TAG"]
    version, build = release_version(tag, os.environ["GITHUB_RUN_NUMBER"], Path("project.yml").read_text())
    with open(os.environ["GITHUB_ENV"], "a") as environment:
        environment.write(f"RELEASE_VERSION={version}\nRELEASE_BUILD={build}\n")
    print(f"Release {tag}: version {version}, build {build}")
