"""Remove only this job's temporary signing material, including on setup failure."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

root = Path(os.environ["RUNNER_TEMP"]) / "bettercam-signing"
search = root / "keychain-search.plist"
if search.exists():
    previous = plistlib.loads(search.read_bytes())
    subprocess.run(["security", "list-keychains", "-d", "user", "-s", *previous], check=True)
keychain = root / "release.keychain-db"
if keychain.exists():
    subprocess.run(["security", "delete-keychain", str(keychain)], check=True)
manifest = root / "profiles.plist"
if manifest.exists():
    for file in plistlib.loads(manifest.read_bytes()):
        Path(file).unlink(missing_ok=True)
Path("Config/Local.xcconfig").unlink(missing_ok=True)
if root.exists():
    shutil.rmtree(root)
