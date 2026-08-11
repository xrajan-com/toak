#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_bundle_id="${IOS_BUNDLE_ID:-com.tenofakind.poker}"

python3 - "$repo_root" "$expected_bundle_id" <<'PY'
from __future__ import annotations

import plistlib
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
expected_bundle_id = sys.argv[2]
project_path = repo_root / "ios/Runner.xcodeproj/project.pbxproj"
info_path = repo_root / "ios/Runner/Info.plist"
firebase_path = repo_root / "ios/Runner/GoogleService-Info.plist"
pod_lock_path = repo_root / "ios/Podfile.lock"
expected_test_bundle_id = f"{expected_bundle_id}.RunnerTests"
issues: list[str] = []


def read_plist(path: Path, label: str) -> dict:
    if not path.is_file():
        issues.append(f"{label} is missing: {path.relative_to(repo_root)}")
        return {}
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
    except Exception as error:
        issues.append(f"{label} is invalid: {error}")
        return {}
    if not isinstance(value, dict):
        issues.append(f"{label} must contain a dictionary.")
        return {}
    return value


if not project_path.is_file():
    issues.append("Xcode project is missing: ios/Runner.xcodeproj/project.pbxproj")
    project_text = ""
else:
    project_text = project_path.read_text(encoding="utf-8")

bundle_ids = re.findall(
    r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);",
    project_text,
)
runner_bundle_ids = [value for value in bundle_ids if not value.endswith(".RunnerTests")]
test_bundle_ids = [value for value in bundle_ids if value.endswith(".RunnerTests")]
if not runner_bundle_ids or set(runner_bundle_ids) != {expected_bundle_id}:
    issues.append(
        "Runner bundle IDs must all be "
        f"{expected_bundle_id}; found {sorted(set(runner_bundle_ids)) or 'none'}."
    )
if not test_bundle_ids or set(test_bundle_ids) != {expected_test_bundle_id}:
    issues.append(
        "RunnerTests bundle IDs must all be "
        f"{expected_test_bundle_id}; found {sorted(set(test_bundle_ids)) or 'none'}."
    )
if "com.example." in project_text:
    issues.append("The Xcode project still contains a com.example bundle ID.")

resource_section_match = re.search(
    r"/\* Begin PBXResourcesBuildPhase section \*/"
    r"(?P<section>.*?)"
    r"/\* End PBXResourcesBuildPhase section \*/",
    project_text,
    flags=re.DOTALL,
)
resource_section = (
    resource_section_match.group("section") if resource_section_match else ""
)
if "GoogleService-Info.plist in Resources" not in resource_section:
    issues.append(
        "GoogleService-Info.plist is not in the Runner Copy Bundle Resources phase."
    )

info = read_plist(info_path, "Runner Info.plist")
photo_reason = info.get("NSPhotoLibraryUsageDescription")
if not isinstance(photo_reason, str) or not photo_reason.strip():
    issues.append(
        "NSPhotoLibraryUsageDescription is required because the profile flow "
        "opens the photo library."
    )

firebase = read_plist(firebase_path, "Firebase iOS configuration")
firebase_bundle_id = firebase.get("BUNDLE_ID")
if firebase_bundle_id != expected_bundle_id:
    issues.append(
        "GoogleService-Info.plist BUNDLE_ID must be "
        f"{expected_bundle_id}; found {firebase_bundle_id or 'missing'}. "
        "Register the production iOS app in Firebase and download a fresh plist."
    )
for key in ("API_KEY", "GOOGLE_APP_ID", "PROJECT_ID"):
    if not firebase.get(key):
        issues.append(f"GoogleService-Info.plist is missing {key}.")

reversed_client_id = firebase.get("REVERSED_CLIENT_ID")
url_schemes = {
    scheme
    for url_type in info.get("CFBundleURLTypes", [])
    if isinstance(url_type, dict)
    for scheme in url_type.get("CFBundleURLSchemes", [])
    if isinstance(scheme, str)
}
if not isinstance(reversed_client_id, str) or not reversed_client_id:
    issues.append("GoogleService-Info.plist is missing REVERSED_CLIENT_ID.")
elif reversed_client_id not in url_schemes:
    issues.append(
        "Runner Info.plist must register the Firebase REVERSED_CLIENT_ID "
        "as a URL scheme."
    )

if not pod_lock_path.is_file():
    issues.append(
        "ios/Podfile.lock is missing; run pod install and commit the lockfile."
    )

development_teams = {
    value.strip().strip('"')
    for value in re.findall(r"DEVELOPMENT_TEAM\s*=\s*([^;]+);", project_text)
    if value.strip().strip('"') and "$(" not in value
}
if not development_teams:
    issues.append(
        "No Apple DEVELOPMENT_TEAM is configured. Select the Runner target's "
        "Signing & Capabilities team in Xcode."
    )

if platform.system() != "Darwin":
    issues.append("Apple signing must be verified on macOS.")
elif shutil.which("security") is None:
    issues.append("The macOS security tool is unavailable; signing cannot be verified.")
else:
    identities = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        check=False,
        capture_output=True,
        text=True,
    )
    identity_output = f"{identities.stdout}\n{identities.stderr}"
    match = re.search(r"(\d+)\s+valid identities found", identity_output)
    if identities.returncode != 0 or match is None or int(match.group(1)) == 0:
        issues.append(
            "No valid Apple code-signing identity is installed in the active keychain."
        )

if platform.system() == "Darwin" and shutil.which("xcodebuild") is not None:
    xcode = subprocess.run(
        ["xcodebuild", "-version"],
        check=False,
        capture_output=True,
        text=True,
    )
    version_match = re.search(r"Xcode\s+(\d+)", xcode.stdout)
    if xcode.returncode != 0 or version_match is None:
        issues.append("The active Xcode version could not be verified.")
    elif int(version_match.group(1)) < 26:
        issues.append(
            "Xcode 26 or newer is required for current App Store uploads."
        )

    destinations = subprocess.run(
        [
            "xcodebuild",
            "-workspace",
            str(repo_root / "ios/Runner.xcworkspace"),
            "-scheme",
            "Runner",
            "-showdestinations",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    destination_output = f"{destinations.stdout}\n{destinations.stderr}"
    missing_platform = re.search(
        r"error:(iOS [^,\n]+ is not installed\.[^}\n]*)",
        destination_output,
    )
    if missing_platform is not None:
        issues.append(missing_platform.group(1))

if issues:
    print("iOS release preflight: FAIL", file=sys.stderr)
    for issue in issues:
        print(f" - {issue}", file=sys.stderr)
    raise SystemExit(1)

print("iOS release preflight: PASS")
print(f" - Runner bundle ID: {expected_bundle_id}")
print(" - Firebase plist matches and is copied into the app bundle")
print(" - Firebase URL scheme and CocoaPods lockfile are present")
print(" - Photo-library purpose string is present")
print(" - Apple development team and code-signing identity are available")
PY
