# KartPad — first Android community release

Full playable **Original Mario Kart Wii and Retro Rewind 6.12.7** on ARM64
Android through Vulkan, using the runtime accepted on the maintainer's Pixel
9 Pro XL. This brings Android's native app, shared icon, chooser, touch editing,
floating stick, player identity, save management, display and controller menus,
Retro installer, networking and local diagnostic tools into the main repository.

## Download

- **`KartPad-v0.4.10-android.1-arm64.apk`** — install this on Android.
- **`KartPad-v0.4.10-android.1-notices.zip`** — installation guide, release notes,
  provenance and third-party licenses; keep with the APK when redistributing.
- **`SHA256SUMS`** — verify both downloads.

[Installation and update guide](https://github.com/chrissotraidis/kartpad/blob/v0.4.10-android.1/docs/INSTALL_ANDROID.md)
· [Build from source](https://github.com/chrissotraidis/kartpad/blob/v0.4.10-android.1/android/README.md)

Android uses an APK, not an IPA. This is a free, direct community release, not a
Google Play listing. Apple downloads remain unchanged: iPhone/iPad in v0.4.10;
Mac and experimental Apple TV in v0.4.9.

Requires ARM64, Vulkan, Android 9/API 28 or newer, and your own supported PAL
RMCP01 revision 0 image. The physical tested device is Pixel 9 Pro XL (API 37,
4096-byte pages); the oldest OS/vendor GPU combinations remain unverified.
No disc image, extracted retail assets, Retro pack, saves, private translated
source, signing keys or device identifiers are included. Compiled AOT game
logic is included under the project's existing, unresolved-rights community
distribution boundary; this release is not a grant of third-party rights.

## Tested and accepted

- Owner-reported Original Grand Prix gameplay with Yoshi/bike/manual drift and
  Razer Kishi; touch controls automatically hide on controller connection.
- Owner-reported Retro Rewind Retro WFC login, worldwide matchmaking and live
  race play at 3x over Wi-Fi. Full results/reconnect are not yet verified.
- Original launches after the prior in-place preview update; fresh save exports
  matched byte-for-byte. The retained Retro profile and custom settings remain.

The public package advances version metadata to **0.4.10-android.1 / code 21**
and uses a dedicated release signer; native libraries must match the accepted
Preview 15/code 20 except for the release-blocking console-serial correction
described below. The public signing transition is not a separately
accepted in-place physical update. The maintainer's working preview is left
installed with all its app data intact.

## Console-serial safety fix (issue #94)

Includes the narrow backport of upstream WiiCompiled
[`e0e362b`](https://github.com/patchzyy/Wiicompiled/commit/e0e362bd992e07784f8ce7fa795cdb496af7b075),
reported by patchzyy. `SCGetProductSN` now writes the full numeric serial as the
four-byte guest value the game expects, rather than a string that can collapse
different console serials to the same online CSNum. The native runtime is
rebuilt with the correction; the pre-fix APK is not released.

This does not reset console identities, friend codes or saves, and cannot
remove bad CSNums already recorded by a server. Affected existing accounts may
need server-admin cleanup. Do not use older previews online or try to bypass a
ban by deleting local data. No specific user's ban is asserted by this finding.

## Known limits

Startup pipeline compilation can cause substantial hitches. Warm/track-dependent
slowdowns remain: recent Pixel windows were roughly 50–59 FPS, not sustained
60 FPS. Start at 1x Native resolution and raise it only if performance permits.
Widescreen and Fill Screen remain experimental. Complete lifecycle, motion,
audio/rumble, multi-controller, other-phone and long-soak coverage remain open.

Use **Export Private Diagnostics…** for locally saved troubleshooting evidence.
This non-debuggable release retains shell profiling and bounded local performance/
thermal logging. There is no automatic diagnostic upload. Review and sanitize
reports before sharing; never attach saves or complete private logs publicly.

**Private preview users:** public and local debug signatures differ. Do not
uninstall or clear data to bypass an update conflict. Keep the working preview,
export both profiles' saves and retain your owned image, then plan migration
separately. Future public updates must retain this public signing identity.
