"""Install signing material into an ephemeral Actions keychain, never into artifacts."""
import base64
import os
from pathlib import Path
import plistlib
import secrets
import shlex
import subprocess


def run(arguments):
    result = subprocess.run(arguments, capture_output=True)
    if result.returncode:
        # Command arguments may contain passwords; never include them in exceptions/logs.
        raise SystemExit(f"Signing setup failed while running {arguments[0]}")
    return result.stdout


def main():
    names = ["APPLE_TEAM_ID", "DEVELOPER_ID_P12_BASE64", "DEVELOPER_ID_P12_PASSWORD",
             "APP_PROFILE_BASE64", "CAMERA_PROFILE_BASE64", "NOTARY_KEY_BASE64",
             "NOTARY_KEY_ID", "NOTARY_ISSUER_ID"]
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise SystemExit("Missing Actions secrets/variables: " + ", ".join(missing))
    os.umask(0o077)
    root = Path(os.environ["RUNNER_TEMP"]) / "bettercam-signing"
    root.mkdir(exist_ok=True)
    keychain = root / "release.keychain-db"
    previous = shlex.split(run(["security", "list-keychains", "-d", "user"]).decode())
    (root / "keychain-search.plist").write_bytes(plistlib.dumps(previous))
    password = secrets.token_urlsafe(32)
    run(["security", "create-keychain", "-p", password, str(keychain)])
    run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)])
    run(["security", "unlock-keychain", "-p", password, str(keychain)])
    run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *previous])
    certificate = root / "developer-id.p12"
    certificate.write_bytes(base64.b64decode(os.environ["DEVELOPER_ID_P12_BASE64"], validate=True))
    run(["security", "import", str(certificate), "-k", str(keychain), "-P",
         os.environ["DEVELOPER_ID_P12_PASSWORD"], "-T", "/usr/bin/codesign"])
    run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
         "-s", "-k", password, str(keychain)])
    certificate.unlink()

    profiles = Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"
    profiles.mkdir(parents=True, exist_ok=True)
    installed = []
    uuids = {}
    # Record each installed path immediately so always() can clean up partial setup.
    for name, identifier in [("APP_PROFILE_BASE64", "de.bettercam.app"),
                             ("CAMERA_PROFILE_BASE64", "de.bettercam.camera")]:
        data = base64.b64decode(os.environ[name], validate=True)
        temporary = root / f"{identifier}.provisionprofile"
        temporary.write_bytes(data)
        profile = plistlib.loads(run(["security", "cms", "-D", "-i", str(temporary)]))
        entitlement = profile["Entitlements"]
        app_id = entitlement.get("com.apple.application-identifier", entitlement.get("application-identifier"))
        team = os.environ["APPLE_TEAM_ID"]
        if app_id != f"{team}.{identifier}" or team not in profile["TeamIdentifier"]:
            raise SystemExit(f"Provisioning profile does not match {identifier} / configured team")
        uuid = profile["UUID"]
        destination = profiles / f"{uuid}.provisionprofile"
        destination.write_bytes(data)
        installed.append(str(destination))
        (root / "profiles.plist").write_bytes(plistlib.dumps(installed))
        uuids[identifier] = uuid

    (root / "notary.p8").write_bytes(base64.b64decode(os.environ["NOTARY_KEY_BASE64"], validate=True))
    # CLI overrides in build_release.sh also apply to XPC and camera targets.
    local = Path("Config/Local.xcconfig")
    local.write_text("CODE_SIGN_STYLE = Manual\nCODE_SIGN_IDENTITY = Developer ID Application\n"
                     "CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO\n"
                     f"DEVELOPMENT_TEAM = {os.environ['APPLE_TEAM_ID']}\n"
                     f"BETTERCAM_APP_PROFILE = {uuids['de.bettercam.app']}\n"
                     f"BETTERCAM_CAMERA_PROFILE = {uuids['de.bettercam.camera']}\n")
    print("Temporary Developer-ID identity and matching provisioning profiles installed.")


if __name__ == "__main__":
    main()
