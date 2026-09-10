# KartPad Android

Android is now a supported community platform. The first release is
[`v0.4.10-android.1`](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.10-android.1),
based on the physically tested Preview 15 runtime: Original gameplay with
Razer Kishi, automatic touch hiding, and owner-reported Retro Rewind 6.12.7
Retro WFC worldwide race play on Pixel 9 Pro XL. Read
[installation, update safety and known limits](../docs/INSTALL_ANDROID.md).
Sustained 60 FPS and complete device/controller coverage are not claimed.

## Build the full playable app on an Apple Silicon Mac

The current scripts target macOS ARM64, with Xcode command-line tools, Python 3,
and the pinned Builder/Android dependencies. Linux/Windows host builds are not
documented as validated. Allow substantial disk space for dependencies and the
private translated graph; the installed app's size is not the build-space cost.

```sh
git clone https://github.com/chrissotraidis/kartpad.git
cd kartpad
git checkout v0.4.10-android.1
./scripts/build-user-ipa.sh bootstrap
./scripts/bootstrap-android-host.sh
./scripts/check-android-host.sh
```

The shared Builder bootstrap prepares the pinned source/tool inputs and optional
Retro profile; it does not build an IPA in this command. Android bootstrap never
accepts SDK licenses or edits unrelated shell/system configuration. If a license
is pending, review and accept it yourself before continuing.

Translate **only your own supported RMCP01 revision 0 image**. The shared
bootstrap prepares the following pinned Retro 6.12.7 input paths:

```sh
./scripts/translate-retro-rewind.sh \
  --image /absolute/path/to/your-owned-game.wbfs \
  --retro-root private/builder/retro-rewind-downloads/6.12.7-extracted/RetroRewind6 \
  --payload private/builder/retro-rewind-downloads/payload.RMCPD00.bin

KARTPAD_ANDROID_PROFILEABLE=1 \
KARTPAD_ANDROID_VERSION_NAME=0.4.10-android.1 \
KARTPAD_ANDROID_VERSION_CODE=21 \
KARTPAD_ANDROID_PACKAGE_FORMAT=aab \
  ./scripts/build-android-game-app.sh private/self-build/retro-rewind/translation

KARTPAD_ANDROID_EXPECTED_VERSION_NAME=0.4.10-android.1 \
  ./scripts/audit-android-bundle.sh android/app/build/outputs/bundle/release/app-release.aab
```

If you already have the authorized complete dual graph, pass its ignored path
instead (the maintainer uses `private/g8-full-translation`). Never upload that
graph, source image, extracted content, saves or signing keys. A fresh checkout
does not include them. Use fresh runtime-source/build paths after changing source
patches: the wrapper reuses an existing prepared source directory.

For a locally installable debug-signed APK, use the same build command with
`KARTPAD_ANDROID_PACKAGE_FORMAT=apk`; it writes
`android/app/build/outputs/apk/debug/app-debug.apk`. Audit it with
`KARTPAD_ANDROID_EXPECTED_VERSION_NAME=0.4.10-android.1 ./scripts/audit-android-package.sh PATH.apk`.
That debug build is for personal testing, not public distribution, and cannot
update a differently signed public app. A source-only fixture is not the game.

For non-debuggable release APK derivation and signing, use
`scripts/derive-android-release-apk.sh` with your own persistent private keystore
and password file. The script uses pinned bundletool, audits both artifacts,
rejects the Android debug identity, and never installs or publishes anything.
Keep signing keys backed up securely outside Git: future in-place updates need
the same key. The unsigned AAB stays local; this is not a Google Play release.

```sh
KARTPAD_ANDROID_KEYSTORE=/absolute/private/path/kartpad-release.p12 \
KARTPAD_ANDROID_KEY_ALIAS=kartpad-release \
KARTPAD_ANDROID_PASSWORD_FILE=/absolute/private/path/password.txt \
  ./scripts/derive-android-release-apk.sh \
    android/app/build/outputs/bundle/release/app-release.aab \
    artifacts/KartPad-v0.4.10-android.1-arm64.apk
```

The keystore and key must use the same password for this simple PKCS12 flow.
Do not put passwords in commands, Git, screenshots or issue reports. This
derivation audits a candidate; it does not authorize publication by itself.

Maintainers: [release packaging, notices and hosted verification](../docs/RELEASING_ANDROID.md).

## Historical development and fixture evidence

The checkpoints below predate first-release authorization on 2026-09-07 and do
not override the release/installation instructions above.

Installation follow-up: Preview 15/code 20 is installed in place; Original boots
and fresh post-race save exports match. The pending-install note below is
historical. Owner physical testing and Kishi acceptance remain open.

Latest candidate: Preview 15/code 20, with the owner's Pixel touch layout as
phone defaults. Audits pass; installation is pending a fresh post-race save
export after unlocking. Preview 14 remains installed. Kishi readiness and exact
hashes: `../docs/iterations/android-preview15-owner-layout-kishi.md`.

Current development checkpoint (2026-09-07): private full-runtime Preview 14,
code 19, is installed in place with unchanged saves. Android game classification,
exportable renderer phase timing, and a differential-tested scalar FPSR fast
path are included. Sustained 60 FPS and full physical parity remain open.
Current evidence and hashes: `../docs/iterations/android-preview14-phase-performance.md`.
Do not merge Android into main or publish private builds.

Earlier checkpoint (2026-09-07): private full-runtime Preview 12,
code 17, is installed in place on the Pixel. The fresh Original save export is
byte-identical across the update. Actual user race play confirms warm slowdown;
60 FPS and full physical/feature acceptance remain open. Export Private
Diagnostics now includes coarse frame-time/CPU/GPU metrics and a bounded local
thermal, battery and display-setting history, without background uploads.
See `../docs/iterations/android-preview12-warm-performance.md` and the
Apple v0.4.10 inventory in `../docs/iterations/android-v0410-parity-performance.md`.
Do not publish private builds or infer gameplay/performance acceptance from the
fixture and packaging checks below.

This directory contains the non-playable Android source-only fixture. A0 proves
the pinned ARM64 toolchain, SDLActivity/JNI entry, SDL Vulkan loader, Dawn
Vulkan adapter discovery, 4 KiB execution, and 16 KiB execution. The first A1
slice additionally creates one Dawn device, byte-verifies a deterministic GPU
clear/readback, presents a separate clear through the Android native window,
and repeats presentation after HOME/foreground surface recreation. The next
A1 slice reserves a dynamic sparse 4 GiB guest range, maps two shared views,
and verifies alias visibility and read-only/guard/read-only protection changes
using the runtime page size. The surface fixture now also retains and
reconfigures its Dawn surface across a physical flipped-landscape sensor
transition, then replaces and presents through three consecutive Android
background/foreground surface generations. The final A1 slice runs the shared
cooperative scheduler for two million deterministic operations and a native
ELF AArch64 fiber for one million context switches with callee-saved register
checks. None of these paths use game data or generated translated code.

The source-only fixture does not establish gameplay, physical-device support,
performance or release readiness. A1 is complete; full A2 acceptance remains open.

Game-runtime builds launch through `KartPadLaunchActivity`, which validates the
pinned Retro Rewind installation before presenting side-by-side Original and
Retro Rewind choices. Selecting an unavailable Retro install opens the
production installer; selecting either playable mode starts the private SDL
activity with one immutable runtime profile. Debug builds retain protected
direct SDL-activity access for device fixtures.

The first A2 build slice can privately prepare and package the complete
29,065-function Original runtime when the ignored translated graph already
exists. This command never copies that graph or game data into Git and does
not publish the resulting APK:

```sh
./scripts/build-android-game-app.sh private/g8-full-translation
./scripts/audit-android-package.sh \
  android/app/build/outputs/apk/debug/app-debug.apk
```

Fixture mode remains the default when the private Gradle properties are not
provided. A full-runtime package is only build/link evidence until separately
staged validated game data boots and completes the A2 gameplay matrix.

In game-runtime mode the APK contains exactly 14 audited public support assets.
`KartPadRuntimeResources` atomically installs them into versioned app-private
storage before SDL loads. The Activity supplies its Context-derived private
files/cache paths to the native runtime, which keeps configuration, logs, NAND,
and writable renderer databases out of both the APK and shared storage. A cold
launch without staged game data must reach the explicit `No DVD root is
configured` boundary; it is not gameplay evidence.

With an already validated ignored RMCP01 DATA directory staged separately in
that private storage, the API 36 emulator now boots and renders the Original
title/demo loop. Six consecutive HOME/foreground surface generations retained
one process and resumed presentation; three more did the same in a live race,
and a saved license survived three cold launches. A controller-driven emulator
run also completed a three-lap race, saved a ghost, and visibly reloaded it
after force-stop/relaunch. See
`docs/artifacts/2026-09-04/android/a2-controller-complete-race-save.md` for the
latest evidence and open failures. A2 remains open for a physical Android
device and controller, tactile rumble, audible output, and performance.

Before changing or installing anything on a physical device, connect exactly
one authorized ADB target and run the read-only A2 intake check:

```sh
./scripts/check-android-physical-device.sh
./scripts/test-android-physical-device-preflight.sh
```

The check rejects emulators and unsupported API, ABI, page-size, or free-space
configurations. It reports whether Android currently exposes a controller
source, the KartPad package, and Vulkan inventory without printing the ADB
serial. A pass is only preflight evidence: the printed manual rows still
require a hands-on physical race, save/relaunch, lifecycle checks, listening,
and tactile rumble confirmation.

Keep a full session log only in an ignored private path, then create a bounded
publishable signal summary without copying arbitrary log lines:

```sh
./scripts/summarize-android-a2-session.py --require-signal-matrix \
  private/android-a2-physical-session.log
```

Strict mode accepts only one capture (or standard input) and requires
controller connection, initialized and non-silent SDL audio with submitted
bytes, one complete surface pause/resume cycle, and no fatal signature. Its
strict lifecycle row also requires the standard-gamepad suspend/resume pair.
Its result is automated runtime evidence only; audible quality, tactile
rumble, race completion, saved-result reload, and performance remain hands-on
checks.

For the physical run, the preferred two-phase wrapper avoids writing raw
logcat to the host at all:

```sh
./scripts/capture-android-a2-session.sh start
# Complete the controller race, lifecycle, listening, and rumble checks.
./scripts/capture-android-a2-session.sh summarize \
  > .android-bootstrap/android-a2-physical-runtime-signals.json
```

`start` records only the device's log timestamp in the ignored bootstrap
directory. `summarize` requests logs from that timestamp for KartPad's package
UID, streams them directly through the strict sanitizer, and emits only JSON
on stdout. ADB errors are suppressed or serial-redacted. Review the JSON before
copying it into a publishable evidence directory.

On an Apple Silicon Mac, explicitly install the pinned public toolchain and
phone, tablet, and 16 KiB AVDs, then verify them:

```sh
./scripts/bootstrap-android-host.sh
./scripts/check-android-host.sh
```

The bootstrap may download several gigabytes. It never accepts licenses or
other legal terms; if the SDK reports an unaccepted term, complete that human
step separately and rerun it. It does not modify shell profiles or unrelated
toolchains.

Build, audit, install, launch, and exercise the API 36 / 4 KiB fixture with one
command:

```sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
```

Repeat the same cold-boot lane on the pinned Android 15 / 16 KiB image:

```sh
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
```

The pinned API 36 Pixel Tablet lane used for A4 layout, hit-map, accessibility,
and lifecycle acceptance is:

```sh
./scripts/run-android-fixture.sh KartPad_API_36_TABLET_ARM64
```

The runner refuses to start when another Android device or emulator is
connected, wipes only the named disposable KartPad AVD, settles it in the
shell's declared landscape orientation, stops it on exit, and keeps raw
emulator output under the ignored `.android-bootstrap/` directory. It drives
HOME/foreground and requires the post-recreation presentation marker. The
produced debug APK remains a local audit fixture and must not be published.
