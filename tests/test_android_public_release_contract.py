from pathlib import Path
import unittest

REPO = Path(__file__).resolve().parents[1]


class AndroidPublicReleaseTests(unittest.TestCase):
    def test_derivation_is_guarded_and_never_installs(self):
        source = (REPO / "scripts/derive-android-release-apk.sh").read_text()
        for required in ("audit-android-bundle.sh", "audit-android-package.sh",
                         "CN=Android Debug", "androiddebugkey", "apksigner",
                         "KARTPAD_ANDROID_EXPECTED_VERSION_CODE", "KARTPAD_ANDROID_REQUIRE_RELEASE",
                         '--ks-pass="file:', '--key-pass="file:', '--mode=universal'):
            self.assertIn(required, source)
        for forbidden in ("adb ", "gh release", "-genkeypair", "pass:android"):
            self.assertNotIn(forbidden, source)

    def test_public_notices_have_provenance_and_exact_signer(self):
        source = (REPO / "scripts/package-android-release-notices.py").read_text()
        for required in ("sourceCommit", "apkSHA256", "nativeLibraries", "noticesSHA256",
                         "containsTranslatedGameCode", "upstreamRightsConfirmed",
                         "certificate_sha256", "CN=Android Debug", '"--porcelain"',
                         "APPROVED_MAIN_SHA256", "issue #94-corrected release library",
                         "GPL-3.0.txt", "Dawn-BSD.txt", "SDL3-Zlib.txt", "package.testzip()"):
            self.assertIn(required, source)

    def test_update_guide_preserves_private_previews(self):
        guide = (REPO / "docs/INSTALL_ANDROID.md").read_text()
        for required in ("Do not uninstall", "both profiles", "different local",
                         "60 FPS", "APK", "SHA256SUMS"):
            self.assertIn(required, guide)


if __name__ == "__main__":
    unittest.main()
