#!/usr/bin/env python3
"""Package allowlisted public notices/provenance beside the separately signed APK."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

TAG = "v0.4.10-android.1"
VERSION = "0.4.10-android.1"
CODE = 21
# Exact corrected native library inspected after the issue #94 rebuild.
APPROVED_MAIN_SHA256 = "e82fae367661d2b08e5356d1b4afb5d5b447925422b0a3092c06210a33adcede"
REPO = Path(__file__).resolve().parents[1]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("aab", type=Path, help="Audited local bundle; never copied to output")
    parser.add_argument("native_build", type=Path, help="Exact arm64-v8a CMake build containing _deps")
    parser.add_argument("--certificate-sha256", required=True)
    args = parser.parse_args()
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=REPO, text=True).strip():
        parser.error("release packaging requires a clean source tree")
    if not re.fullmatch(r"[0-9a-f]{64}", args.certificate_sha256):
        parser.error("expected lowercase SHA-256 certificate fingerprint")
    if args.apk.name != f"KartPad-{TAG}-arm64.apk":
        parser.error("unexpected APK filename")
    env = dict(os.environ, KARTPAD_ANDROID_EXPECTED_VERSION_NAME=VERSION,
               KARTPAD_ANDROID_EXPECTED_VERSION_CODE=str(CODE), KARTPAD_ANDROID_REQUIRE_RELEASE="1")
    env["JAVA_HOME"] = str(REPO / ".android-bootstrap/jdk-17.0.20.1+1/Contents/Home")
    for script, path in (("audit-android-bundle.sh", args.aab), ("audit-android-package.sh", args.apk)):
        subprocess.run([str(REPO / "scripts" / script), str(path.resolve())], env=env, check=True)
    sdk = Path(env.get("ANDROID_SDK_ROOT", env.get("ANDROID_HOME", str(Path.home() / "Library/Android/sdk"))))
    cert = subprocess.check_output([str(sdk / "build-tools/36.0.0/apksigner"), "verify",
                                    "--print-certs", str(args.apk)], env=env, text=True)
    fingerprints = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)", cert)
    if fingerprints != [args.certificate_sha256] or "CN=Android Debug" in cert:
        parser.error("signature does not match the single approved release identity")
    deps = args.native_build / "_deps"
    entries = {
        "LICENSE": REPO / "LICENSE",
        "INSTALL_ANDROID.md": REPO / "docs/INSTALL_ANDROID.md",
        "BUILD_ANDROID.md": REPO / "android/README.md",
        "RELEASE_NOTES.md": REPO / f"docs/releases/{TAG}.md",
        "RIGHTS_AND_LICENSES.md": REPO / "RIGHTS_AND_LICENSES.md",
        "THIRD_PARTY_NOTICES.md": REPO / "THIRD_PARTY_NOTICES.md",
        "dependencies.lock.json": REPO / "dependencies.lock.json",
        "LICENSES/GPL-3.0.txt": REPO / "LICENSES/GPL-3.0.txt",
        "ThirdPartyLicenses/Aurora-MIT.txt": REPO / "ref/upstream/Wiicompiled/aurora-main/LICENSE",
        "ThirdPartyLicenses/WiiCompiled-GPL-3.0.txt": REPO / "ref/upstream/Wiicompiled/LICENSE",
        "ThirdPartyLicenses/Dolphin-COPYING.txt": REPO / "ref/upstream/dolphin/COPYING",
        "ThirdPartyLicenses/Dolphin-Externals.md": REPO / "ref/upstream/dolphin/Externals/licenses.md",
        "ThirdPartyLicenses/Apache-2.0.txt": REPO / "ref/upstream/dolphin/Externals/Vulkan-Headers/LICENSES/Apache-2.0.txt",
        "ThirdPartyLicenses/Mbed-TLS.txt": REPO / ".android-bootstrap/dependencies/mbedtls-4.1.1/LICENSE",
        "ThirdPartyLicenses/Minizip-NG.txt": REPO / ".android-bootstrap/dependencies/minizip-ng-55db144e03027b43263e5ebcb599bf0878ba58de/LICENSE",
        "ThirdPartyLicenses/Dawn-BSD.txt": REPO / ".android-bootstrap/dependencies/Dawn-13abc3bc-LICENSE.txt",
    }
    for label, filename in {
        "Abseil-Apache-2.0.txt": "abseil-cpp-src/LICENSE",
        "FreeType.txt": "freetype-src/LICENSE.TXT",
        "Tracy-BSD-3-Clause.txt": "tracy-src/LICENSE",
        "fmt-MIT.txt": "fmt-src/LICENSE",
        "imgui-MIT.txt": "imgui-src/LICENSE.txt",
        "libpng.txt": "png-src/LICENSE",
        "xxHash-BSD-2-Clause.txt": "xxhash-src/LICENSE",
        "zstd-BSD.txt": "zstd-src/LICENSE",
    }.items():
        entries[f"ThirdPartyLicenses/{label}"] = deps / filename
    data = {name: path.read_bytes() for name, path in entries.items()}
    if sha(data["ThirdPartyLicenses/Dawn-BSD.txt"]) != "e2908f7576fb12be5bdb8480cddb0be62badb498cadb821d043aeaf01b0b0899":
        parser.error("Dawn license does not match the release's pinned source")
    with zipfile.ZipFile(REPO / ".android-bootstrap/dependencies/SDL3-devel-3.4.4-android.zip") as sdl:
        data["ThirdPartyLicenses/SDL3-Zlib.txt"] = sdl.read("LICENSE.txt")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    with zipfile.ZipFile(args.apk) as apk:
        native = {n: sha(apk.read(n)) for n in apk.namelist() if n.startswith("lib/") and n.endswith(".so")}
    if native.get("lib/arm64-v8a/libmain.so") != APPROVED_MAIN_SHA256:
        parser.error("runtime is not the approved issue #94-corrected release library")
    provenance = {
        "schemaVersion": 1, "releaseTag": TAG, "sourceCommit": commit,
        "appVersion": VERSION, "versionCode": CODE, "package": "dev.kartpad.android",
        "apkSHA256": sha(args.apk.read_bytes()), "apkBytes": args.apk.stat().st_size,
        "aabSHA256": sha(args.aab.read_bytes()), "aabBytes": args.aab.stat().st_size,
        "signingCertificateSHA256": args.certificate_sha256, "nativeLibraries": native,
        "containsTranslatedGameCode": True, "containsGameData": False,
        "containsPrivateSigningMaterial": False, "maintainerAuthorizedFreeCommunityRelease": True,
        "upstreamRightsConfirmed": False, "profileableByShell": True, "debuggable": False,
        "physicalAcceptance": "Preview 15 native runtime; owner Pixel 9 Pro XL Original/Kishi and Retro WFC live race reports",
        "noticesSHA256": {n: sha(b) for n, b in sorted(data.items())},
    }
    data["PROVENANCE.json"] = (json.dumps(provenance, indent=2, sort_keys=True) + "\n").encode()
    output = args.apk.parent / f"KartPad-{TAG}-notices.zip"
    with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for name, content in sorted(data.items()):
            if b"/Users/" in content or len(content) > 2_000_000:
                parser.error(f"unexpected private path or oversized notice: {name}")
            info = zipfile.ZipInfo(name, date_time=(2026, 9, 7, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            package.writestr(info, content)
    with zipfile.ZipFile(output) as package:
        assert sorted(package.namelist()) == sorted(data) and package.testzip() is None
        for name, content in data.items():
            assert package.read(name) == content
    checksum_path = args.apk.parent / "SHA256SUMS"
    with checksum_path.open("x") as checksums:
        for artifact in (args.apk, output):
            checksums.write(f"{sha(artifact.read_bytes())}  {artifact.name}\n")
    print(f"Packaged {len(data)} allowlisted notices/provenance entries; no private inputs copied.")
    print(output)


if __name__ == "__main__":
    main()
