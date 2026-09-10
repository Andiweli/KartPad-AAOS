# Install KartPad on Android

## Download and first launch

1. Open the [first Android release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.10-android.1).
   Download `KartPad-v0.4.10-android.1-arm64.apk`, `SHA256SUMS`, and the companion
   notices ZIP. APK is Android's installable format; IPA is Apple-only. The AAB
   is a developer bundle and is not needed for installation (it is not published).
2. Use an ARM64 phone/tablet with Vulkan and Android 9/API 28 or newer. The
   tested physical device is Pixel 9 Pro XL; the oldest OS/vendor GPU combinations
   and all other phones are not certified. Allow at least 6 GiB free for setup,
   plus space for the source image and optional Retro Rewind installation.
3. Verify the APK against `SHA256SUMS` (`shasum -a 256 FILE.apk` on macOS,
   `sha256sum FILE.apk` on Linux, or `Get-FileHash FILE.apk -Algorithm SHA256`
   in PowerShell). Open it on the phone and, if requested, allow that browser or
   file manager to install this app. No USB debugging is required for normal
   installation. Revoke that install permission afterward if you enabled it.
4. Open KartPad, choose Original, and import your own supported PAL **RMCP01
   revision 0** WBFS/ISO using the system picker. A filename/extension alone is
   not sufficient: the exact profile's identity checks must pass. Keep the
   original image backed up; neither the APK nor this repository supplies it.
5. Choose Retro Rewind to download, verify and install the separately hosted
   official **6.12.7** pack. Use matching current content; if KartPad reports a
   newer incompatible profile, wait for a matching KartPad update. Never bypass
   the checks or replace executable files manually.

## Updating safely

Install future public APKs over the existing public app. Keep the same signing
identity and use a forward version code. Export saves for **both profiles**
through **Game Data & Saves → Manage Saves…** before updating, and keep your
owned image separately. Save export is not a complete backup of preferences,
Miis or downloaded content. Never uninstall or clear storage as an update step.

**Private preview users:** earlier hardware previews use a different local
debug certificate. Android will reject the public release as an in-place update
over those previews. Do not uninstall to force it through: preserve the working
preview and its app data, and plan a deliberate backed-up migration separately.
The maintainer's tested Pixel was deliberately left on Preview 15/code 20.
The public package is code 21; changing its signature is not a save migration.
Self-built APKs similarly cannot update public builds unless the signer matches.

Earlier previews also lack the issue #94 console-serial correction. Do not use
those builds online. The fix writes the full numeric serial expected by the
game; it does not reset your identity or saves. Incorrect CSNums already stored
in a server account's history may require server-admin cleanup. Do not delete
licenses, regenerate identities or clear app data to work around a server ban.

## Controls and performance

The three-dot menu contains Controls, Display, Game Data & Saves, Multiplayer,
and local reporting tools. Touch controls are movable, resizable and hideable;
the floating movement stick follows your initial thumb position within its
pickup area. Existing custom layouts are preserved.

The maintainer accepted Original Grand Prix gameplay using Razer Kishi, with
touch controls hiding automatically when connected. The default mapping is
A/B/X/Y directly, left stick to steer, Start to pause, left shoulder to Z,
left trigger to L, and right shoulder/right trigger to R. Check your exact
controller model; reconnect, rumble, multiple pads and every Kishi generation
are separate acceptance cases.

Start with **Display → Render Resolution → 1x Native**. Increase resolution if
performance permits. Original 4:3 is the conservative aspect setting; widescreen
and Fill Screen remain experimental. Pixel play at 3x was accepted, but the
initial pipeline-compilation queue can cause pronounced hitches, and warm or
track-dependent slowdown remains. This release does not promise sustained 60 FPS.
Retro WFC login, worldwide matchmaking and live race play were owner-reported;
complete results, reconnect and network-transition coverage remain open.

## Report a problem

Include the Android app version, phone model, OS/API, game/profile and track,
render resolution/aspect, controller model, how long it ran, and whether it was
a cold or repeat launch. Enable **Show FPS Counter** and describe when it dips.
Use **Export Private Diagnostics…** to save logs locally after reproducing it.
Runtime, renderer-phase and bounded battery/thermal diagnostics are retained
locally; the app does not upload those reports automatically. Shell profiling
is enabled in this first release, but the app is non-debuggable.

Review diagnostics before sharing; do not attach raw private archives, game
images, extracted assets, saves, account/device identifiers or signing keys to
public issues. [Open an issue](https://github.com/chrissotraidis/kartpad/issues)
with the minimal sanitized report. A clean compile or emulator FPS is not proof
of physical performance.

For source builds, see [android/README.md](../android/README.md). See
[rights and licenses](../RIGHTS_AND_LICENSES.md) for the community-release boundary.
