"""One-time setup: send explicitly supplied files to encrypted repository Actions secrets."""
import argparse
import base64
import getpass
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--repo", required=True, help="OWNER/REPO")
parser.add_argument("--team-id", required=True)
parser.add_argument("--certificate", type=Path, required=True, help="Exported Developer ID identity (.p12)")
parser.add_argument("--app-profile", type=Path, required=True)
parser.add_argument("--camera-profile", type=Path, required=True)
parser.add_argument("--notary-key", type=Path, required=True, help="App Store Connect Team API key (.p8)")
parser.add_argument("--notary-key-id", required=True)
parser.add_argument("--notary-issuer-id", required=True)
args = parser.parse_args()

# Read all inputs before making any remote changes; never display their contents.
values = {name: base64.b64encode(path.read_bytes()) for name, path in {
    "DEVELOPER_ID_P12_BASE64": args.certificate,
    "APP_PROFILE_BASE64": args.app_profile,
    "CAMERA_PROFILE_BASE64": args.camera_profile,
    "NOTARY_KEY_BASE64": args.notary_key,
}.items()}
values["DEVELOPER_ID_P12_PASSWORD"] = getpass.getpass("P12 export password: ").encode()
values["NOTARY_KEY_ID"] = args.notary_key_id.encode()
values["NOTARY_ISSUER_ID"] = args.notary_issuer_id.encode()
for name, value in values.items():
    result = subprocess.run(["gh", "secret", "set", name, "--repo", args.repo], input=value, capture_output=True)
    if result.returncode:
        raise SystemExit(f"Could not save {name}; check gh authentication and repository permissions")
    print(f"Saved {name}")
subprocess.run(["gh", "variable", "set", "APPLE_TEAM_ID", "--repo", args.repo, "--body", args.team_id], check=True)
print("Release signing setup saved. Run the Release macOS workflow for a release tag to verify it.")
