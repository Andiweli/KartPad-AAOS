# KartPad Android/AAOS

KartPad is a Fork of [KartPad](https://github.com/chrissotraidis/kartpad) which is a Mario Kart Wii port for Android, iOS and others. KartPad adds a first-class dual-game Original Mario Kart Wii / Retro Rewind runtime, native platform controls, data management, packaging, and release workflows.

This repository focusses on an optimized Android version, with recompiled .so Files, optimized native TLS, improved floating-point calculations and utilization of high-performance CPU cores. It was thus possible to achieve a nearly smooth 50–60 FPS on an AAOS vehicle equipped with an SA8155P board.

### How to install?

Requires an **ARM64 Android device with Vulkan** and your own supported PAL
`RMCP01` revision 0 image. The package minimum is Android 10/API 29. Start at **1x Native** resolution
and increase it if your phone maintains good performance. If you have poor performance at **1x Native** you can try the new scaled down resolutions **0.5x** or **0.75** which pump up the FPS a little bit but with slightly lower resolution.

### Platform overview

| Question | Answer |
|---|---|
| Is this Dolphin or streaming? | No. WiiCompiled translates the game's PowerPC code ahead of time, then KartPad compiles it for ARM64 and presents it through Metal on Apple platforms or Vulkan on Android. |
| Are release downloads included? | **Yes.** Corrected downloads: iPhone/iPad `v0.4.11`, Mac `v0.4.11-macos.1`, Android `v0.4.10-android.1`. Experimental tvOS has the same correction in `v0.4.11-tvos.1`. Supply your own supported game data; the IPA also requires local re-signing. |
| Can the source create an IPA? | Yes. The Personal IPA Builder can also translate a supported user-owned game executable and create a separate private unsigned IPA on an Apple Silicon Mac. |
| Does it include Mario Kart Wii? | No. You must provide your own legally obtained supported PAL `RMCP01` revision 0 WBFS/ISO. |
| Does it support Retro Rewind? | **Yes.** Choose Original Mario Kart Wii or Retro Rewind when KartPad opens. KartPad can download, verify, and install the official Retro Rewind 6.12.7 pack. The maintainer accepted Retro Rewind launch and menu navigation on iPad build 25; production online races remain a separate check. |
| Does online play work? | The online-capable build passes login, matchmaking, a two-player race, results, ratings, and lobby return against a compatible isolated WFC server. Retro WFC is active again as of 6 September 2026. Production online races for the distributed builds still need end-to-end physical-device verification. |
| Do touch, tilt, and controllers work? | Touch, motion steering, and ordinary GameController-compatible pads are implemented, with general physical acceptance on iPhone and iPad. Direct Wii Remote/Nunchuk pairing is a separate experimental, macOS-only path that still needs external hardware testing. |
| Can I rename or delete a license? | **Yes on iPhone and iPad.** Open **Game Data & Saves → Player Identity… → Rename or Delete Licenses…**, choose the exact game profile and slot, then rename it without losing its friend code/progress or delete only that slot after a second warning. Fully close KartPad from the app switcher and reopen it to apply the backed-up change; returning to its menu and resuming does not apply pending edits. |
| Can I choose a Mii appearance? | **Appearance import remains experimental.** Open **Game Data & Saves → Player Identity… → Import Mii Appearance…** and choose a standard 74-byte `.mii` file. **Remove Mii Appearance…** never means delete a game license and refuses to remove a Mii that is still linked to one. |
| Are Android and Apple TV supported? | **Android is supported**, with the first APK in `v0.4.10-android.1` and physical Pixel/Kishi gameplay acceptance. Hardware coverage and performance limits are described above. Apple TV remains an experimental hardware-bring-up IPA in `v0.4.11-tvos.1`. |
| Where are Android saves, and can I transfer a PC save? | Original save export/restore is available through **••• → Game Data & Saves → Manage Saves…**. Saves are internal app-private files. Retro Rewind save transfer is not covered by that UI yet; see the [transfer guide](docs/SUPPORT.md#android-save-transfer). |
| Is Wiimmfi supported for Original? | No; it is an open compatibility request [#90](https://github.com/chrissotraidis/kartpad/issues/90). Changing a server address/MAC or importing a patched ISO does not add the matching native executable support. |
| Can I use AirPlay or an external display? | This is under investigation in [#100](https://github.com/chrissotraidis/kartpad/issues/100); phone/tablet display acceptance does not establish external-output support. |
| How much storage does it need? | The app is about 80 MiB and extracted Mario Kart Wii data uses about 2.5 GiB. Retro Rewind downloads an additional 1.72 GiB archive and needs temporary installation space. Keeping the WBFS/ISO on the device requires more space. |

## Original Mario Kart Wii or Retro Rewind

KartPad now treats Retro Rewind as a first-class optional game mode rather than
an unrelated setup path. The opening screen offers two choices:

- **Mario Kart Wii** starts the original game with its original tracks,
  characters, saves, local multiplayer, and KartPad controls.
- **Retro Rewind** adds its expanded tracks, characters, features, and Retro
  WFC integration while using the same native KartPad runtime and controls.

On iPhone and iPad in 0.4.10, open **••• → Return to KartPad Menu** to pause
the current game and return to the chooser. **Resume** continues that same
session. The other game is labeled **Switch on next launch**: choose **Use on
Next Launch**, fully close KartPad from the app switcher, then reopen it.
Returning to the chooser alone does not restart the game or apply pending
license edits. An online connection may time out while the game is paused.

Original Mario Kart Wii no longer offers the unusable private friend-room
instructions. **Experimental Server Settings…** is an override for an
already-running compatible Wii service; it does not create a private lobby.
Retro Rewind retains **Retro WFC Friend Rooms…** guidance. Native MeleePad-style
room hosting and joining remain unfinished.

KartPad does not bundle either game's private data. After you import your own
supported Mario Kart Wii image, choosing Retro Rewind checks the official
version feed, downloads the matching official full pack, verifies its exact
size and SHA-256 identity, and installs it atomically. The accepted physical
iPad flow completed the full 6.12.4 download, verification, installation,
launch, and a playable single-player match.

Retro Rewind requires matching current content for online compatibility.
KartPad checks the official version before every Retro Rewind launch. If Retro
Rewind advances beyond the ahead-of-time profile included in KartPad, the app
asks for a compatible KartPad update instead of launching an outdated build.
After that KartPad update is installed, selecting Retro Rewind guides the user
through installing the newly matched official pack.

Retro WFC is Retro Rewind's online service. KartPad's online-capable graph
passes login, matchmaking, a complete two-player race, results, ratings, and
lobby return against a compatible isolated WFC service. Retro WFC's public
health and room feeds are active again as of 6 September 2026. That service
recovery does not by itself prove the distributed KartPad builds' production
login, matchmaking, complete-race, results, reconnect, or physical-device gates.

KartPad packages a native ARM64 app around a
[WiiCompiled](https://github.com/patchzyy/Wiicompiled)-generated Mario Kart Wii
module and its Aurora/Dawn compatibility runtime. PowerPC game code runs as
ahead-of-time translated arm64 code, Dawn presents through Metal or Vulkan, and
platform host layers supply audio, input, storage, timing, and lifecycle behavior.

This repository contains KartPad's Apple and Android integration, reproducible patches,
tests, documentation, and original artwork. The source tree does **not** contain
Mario Kart Wii, a disc image, extracted Nintendo assets, generated game code,
saves, or signing material. The separately downloadable preview IPAs contain
the compiled ahead-of-time translation described in
[`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md), but none of the remaining
retail game data.

## Game data

KartPad never downloads or bundles Nintendo data. Development uses a locally
owned PAL `RMCP01` revision 0 image that is verified, kept read-only, and
ignored by Git. Extracted files, translations, caches, saves, logs, and private
captures stay in ignored local directories.

On iPhone and iPad, first launch stops before emulation and accepts either the
supported private `RMCP01` WBFS/ISO image or an extracted `DATA` folder.
KartPad opens the image with a narrow native DiscIO importer, verifies the game
identity and revision, extracts the runtime files on-device, validates the
critical DOL, and atomically activates the protected private tree. Interrupted
imports recover or roll back; replacement never silently discards the last
valid copy. Removal is explicit, undoable until relaunch, and occurs before
emulation while preserving saves.

The translated ARM64 graph is compiled and signed on the Mac. The mobile app
imports non-executable game data only; it contains no PowerPC JIT, runtime
compiler, or executable-code download.

| Game ID | Region | Revision | Accepted input |
|---|---|---|---|
| `RMCP01` | PAL / Europe | 0 | One exact pinned WBFS container for the current development profile |

Other regions, revisions, dumps, and container hashes fail closed even when
their filename extension is recognized. The expected digest is recorded in
the build scripts for identification; no disc content is tracked or
distributed.

## Player identity, experimental Mii appearances, and Wii Remote controls

License and player-name editing is supported on iPhone, iPad and Mac in 0.4.9.
Imported Mii appearances and direct Wii Remote controls remain opt-in features for community
testing until users with real exported Miis and original Wii hardware complete
the remaining acceptance checks.

### Rename or delete an existing license

Open **••• → Game Data & Saves → Player Identity… → Rename or Delete
Licenses…**. KartPad lists each active license as **Original Mario Kart Wii** or
**Retro Rewind**, followed by its one-based slot and current name.

- Choose **Rename License…** to keep that slot's friend code, online account,
  records, and progress while changing its displayed and online name.
- Choose **Delete License…** only for the exact unwanted slot. A second warning
  names the profile and slot because deletion removes that license's friend
  code, account data, records, and progress.
- Fully close KartPad from the app switcher and reopen it before playing.
  Returning to the KartPad menu and resuming does not apply pending edits. The
  newest live save is revalidated and backed up before the change is applied.
- Deleting a license leaves the other slots in place. Deleting slot 1 does not
  move the license in slot 2 into slot 1.

If an older license already has a friend code and a newly created duplicate
does not, rename the established license first. Verify its friend code remains,
then delete the empty duplicate. Do not delete the established license merely
to change its name.

### Set a Mii name or appearance

On iPhone or iPad, open **Game Data & Saves → Player Identity…**. Choose **Edit
Mii Name…** to give the built-in or an imported Mii a 1–10 character name.
On the next launch, KartPad updates that Mii and every linked original-game or
Retro Rewind license while retaining friend codes, online account data, and
progress. This edits your Mii identity; it does not create a game license.
To create one, choose **New** on the license screen inside Mario Kart Wii or
Retro Rewind, then select that Mii. The new license inherits its name.

**Edit Mii Name…** remains available for naming a Mii and every license that
is already linked to it. For an older or unlinked license, use **Rename or Delete
Licenses…** instead.

KartPad still does not include the Wii Menu's full appearance editor. To change
the face or other appearance details, create or export a standard 74-byte
`.mii` with a compatible tool and choose **Import Mii Appearance…**. **Remove
Mii Appearance…** removes only an unused appearance, never a license, and is
blocked while a license still references that Mii. Changes
are staged, the Mii database and save are checksum-validated, and both are
backed up before replacement. Do not attach a complete NAND, save, or app
container to a public issue.

### Pair a Wii Remote and Nunchuk on macOS

The macOS build has an opt-in **Controls → Experimental Wii Remote + Nunchuk**
path for an original `RVL-CNT-01` or Wii Remote Plus `RVL-CNT-01-TR`. It pairs
directly through the Mac's Bluetooth hardware without a DolphinBar, then hands
the controller to SDL and exposes a **Wii Remote + Nunchuk (Experimental)**
preset in Controller Settings.

This pairing path uses private macOS Bluetooth interfaces and is intended for
direct testing, not the Mac App Store. Actual pairing, Nunchuk input, reconnect,
and long-session behavior still require reporter hardware acceptance. iPhone
and iPad show the experimental control entry for clarity, but iOS/iPadOS do not
provide the required direct Wii Remote HID pairing path.

## Install or build

### Download the Apple Silicon Mac app

Download `KartPad-v0.4.11-macos.1-arm64.zip` and `SHA256SUMS` from the
[macOS release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-macos.1).
The app is ad-hoc signed, requires macOS 14 or newer on Apple Silicon, and does
not include Mario Kart Wii or Retro Rewind data. Follow
[`docs/INSTALL_MACOS.md`](docs/INSTALL_MACOS.md) for checksum, Gatekeeper, game
data, game switching, keyboard, controller, and mouse guidance.

### Download the unsigned iPhone/iPad IPA

Download `KartPad-v0.4.11-ios-unsigned.ipa` and `SHA256SUMS` from the
[0.4.11 release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11).
Verify the checksum, re-sign the IPA with AltStore Classic plus AltServer or
another compatible personal-signing workflow, and select your own supported
PAL `RMCP01` revision 0 image on first launch. See
[`docs/INSTALL_IPA.md`](docs/INSTALL_IPA.md) for the complete boundary and
update-preservation guidance.

### Test the experimental Apple TV build

The same release includes `KartPad-v0.4.4-tvos-unsigned.ipa` for a
small physical-hardware bring-up cohort. It has passed native build and package
audits but has not run on the maintainer's Apple TV hardware. Re-sign it for
your paired Apple TV, stage your own supported extracted data, and follow
[`docs/TVOS-TESTING.md`](docs/TVOS-TESTING.md). See
[`docs/INSTALL_TVOS.md`](docs/INSTALL_TVOS.md) for the installation boundary.

### Build a personal unsigned IPA

KartPad's public Builder can instead perform static recompilation on the user's
Apple Silicon Mac before signing:

```sh
./scripts/build-user-ipa.sh bootstrap
./scripts/build-user-ipa.sh inspect /path/to/Mario-Kart-Wii.wbfs
./scripts/build-user-ipa.sh build /path/to/Mario-Kart-Wii.wbfs
```

The resulting `artifacts/KartPad-personal-unsigned.ipa` remains an ignored local
artifact because it contains translated code from the user's game executable,
whose redistribution rights KartPad does not clear. This publication policy
does not restrict your rights to the GPL-covered software. Compatibility is
profile-driven: additional verified WBFS/ISO containers can share a profile only when their extracted executables
are identical, while different regions or revisions use separate profiles.
See [`docs/BUILDER.md`](docs/BUILDER.md) for the cache, validation, extension,
and release contracts. Maintainers should also follow
[`docs/UPSTREAM_UPDATES.md`](docs/UPSTREAM_UPDATES.md) when advancing either
WiiCompiled or Retro Rewind.

### Development workflows

You need:

- an Apple Silicon Mac running macOS 14 or newer;
- Xcode and its command-line tools;
- CMake, Ninja, Git, ripgrep, Python 3, the .NET 8 SDK, and Rust/Cargo;
- `nodtool` 2.0.0-alpha.9; and
- your own legally obtained supported Mario Kart Wii `RMCP01` revision 0 image.

Install the pinned extractor if it is not already available:

```sh
cargo install nodtool --version 2.0.0-alpha.9 --locked
```

Verify the pinned public sources and private input boundary:

```sh
./scripts/verify-sources.sh
./scripts/check-repo-safety.sh
```

Run the portable correctness gates:

```sh
./scripts/test-host-portability.sh
./scripts/test-guest-memory.sh
./scripts/test-guest-scheduler.sh
./scripts/test-ppc-semantics.sh
```

Build from the pinned supported image in one fail-closed local workflow:

```sh
./scripts/self-build-macos.sh /path/to/your/Mario-Kart-Wii.wbfs
```

The workflow bootstraps and verifies the pinned public sources plus the exact
Retro Rewind 6.12.7 pack, verifies the complete supported image hash, extracts
it read-only with pinned `nodtool`, validates `RMCP01` revision 0 plus the
DOL/REL hashes, translates the dual private title graph with bounded
parallelism, builds the patched Apple runtime, and audits the ad-hoc-signed
local app. All extracted and translated outputs stay under ignored `private/`;
the app stays under ignored `build/`. Existing valid work can be resumed.

The initial translation and native build are substantial. The workflow reuses
validated extraction and translation outputs after an interruption. Bootstrap
fetches missing pinned dependencies and fails closed if a source checkout,
Retro Rewind file, or Retro-WFC payload has the wrong identity.

Launch the audited local app:

```sh
open build/KartPad-self-built.app
```

The resulting app is a local development build. It is ignored by Git, may
contain a locally generated executable game module, and must not be
distributed.

To build from an already produced ignored translation graph, run the lower
level steps directly:

```sh
./scripts/prepare-g7-game-runtime.sh
./scripts/package-macos-runtime.sh \
  "$PWD/build/g7-game-runtime-build" \
  "$PWD/build/KartPad.app"
./scripts/audit-macos-package.sh "$PWD/build/KartPad.app"
```

Prepare and build the complete iOS Simulator runtime from the same private
translation graph:

```sh
./scripts/build-ios-discio-probe.sh \
  ref/upstream/dolphin \
  build/dolphin-ios-discio-iphonesimulator-source \
  build/dolphin-ios-discio-iphonesimulator-build \
  iphonesimulator
./scripts/prepare-ios-game-runtime.sh \
  private/g8-full-translation \
  build/ios-game-runtime-source \
  build/ios-game-runtime-build
./scripts/build-ios-game-app.sh \
  build/ios-game-runtime-source \
  build/ios-game-app-xcode \
  private/g8-full-translation
```

Prepare the corresponding unsigned physical-device package without signing or
installing it:

```sh
./scripts/build-ios-discio-probe.sh \
  ref/upstream/dolphin \
  build/dolphin-ios-discio-iphoneos-source \
  build/dolphin-ios-discio-iphoneos-build \
  iphoneos
./scripts/build-ios-device-game-app.sh \
  build/ios-game-runtime-source \
  build/ios-device-game-app-xcode \
  private/g8-full-translation
```

The build scripts verify the exact SunPad source snapshot and dependency pins,
compile only ARM64 code, and fail if private game data, saves, signing material,
or non-system dynamic dependencies enter the app bundle. Installation and
signing remain local development steps; this repository does not publish a
playable app artifact.

See [`docs/GOAL-LOOP.md`](docs/GOAL-LOOP.md) for the execution rules and
[`docs/JOURNAL.md`](docs/JOURNAL.md) for reproducible commands and dated
results.

## First launch on Mac

The one-command build has already prepared the supported private data tree.
Open `KartPad-self-built.app`; if the app asks for game data, choose the
extracted `RMCP01` folder containing `sys/` and `files/`. KartPad validates the
identity before starting the runtime and preserves the previous valid setting
if a replacement is rejected.

Use the normal Mac menu bar instead of a three-dot overlay:

- **Game → Original Mario Kart Wii** or **Game → Retro Rewind** selects the
  game for the next launch. Switching preserves the other profile's saves and
  settings.
- **Data** chooses or replaces the validated Mario Kart Wii and Retro Rewind
  folders, manages Miis, and opens KartPad's data and cache locations.
- **Controls** opens controller mapping, shows the complete keyboard reference,
  and contains the experimental direct Wii Remote pairing controls.
- **Help → Save Diagnostics Report…** creates a bounded report for an issue.

The Mac defaults fresh configurations to 2× rendering; **KartPad → Settings…**
can change resolution, display mode, audio, and the FPS counter. Durable saves
and configuration live in `~/Library/Application Support/KartPad`;
regenerable graphics data lives in `~/Library/Caches/KartPad`.

## Controls and mobile direction

The macOS keyboard bridge maps `WASD` to steering, `U`/Return to
A/accelerate/confirm, `M`/Delete to B/brake/reverse/back, `E` to R/drift,
Left Shift to L/item, arrows to the D-pad/tricks, Space to Start/pause, and Tab
to Select/minus. The native **Controls…** panel (`Command-/`) keeps the full
mapping visible in the app. Native controller discovery, remapping, and four
stable local slots are implemented separately from the keyboard fallback.
The mouse or trackpad operates native menus and settings and the cursor remains
visible; gameplay itself uses the keyboard or a mapped controller because
Mario Kart Wii has no mouse-driving input.

The iPhone/iPad app compiles a byte-identical pinned snapshot of SunPad's GPLv3
touch-control component and persistent **•••** menu directly. It preserves the
component's independently editable phone/tablet layouts, safe-area treatment,
multitouch, accessibility labels, settings, diagnostics, and controller-handoff
behavior. A separate tested adapter supplies Mario Kart Wii's Classic Controller
ABI without changing the copied baseline.

The landscape touch surface keeps every Wii Classic Controller action
available without a separate controller:

- **Left:** steering stick, D-pad, L, Start, and Select within thumb reach. The
  D-pad performs tricks and wheelies; it is not required for basic steering.
- **Right:** action buttons, R/ZL/ZR, and a second stick for menu-compatible
  input.
- **Mario Kart shoulders:** R is a compact digital control matching L rather
  than SunPad's Sunshine-specific analog-pressure trigger.
- **Acceleration lock:** hold A for one uninterrupted second to turn it cyan,
  add light haptic feedback, and keep accelerating after lifting your finger.
  Tap A again to unlock it. Opening a modal, hiding touch controls, or handing
  Player 1 to a controller also clears the lock.
- **Customize:** move and resize controls independently, select any control to
  hide or restore it, and use **Back** to return directly to Touch Control
  Settings. The floating movement stick appears under your thumb within its
  pickup area and disappears on release. Phone and tablet arrangements remain
  separate; new/reset iPad layouts follow the phone arrangement with a reachable
  right-side Start button. The D-pad defaults to hidden. Existing custom
  layouts and explicit visibility choices are preserved.
- **Controller handoff:** the first extended controller takes Player 1, clears
  held touch input, and hides touch controls by default. Disconnecting it
  restores touch; additional controllers keep stable Player 2–4 slots.
- **Menu:** the persistent **•••** opens display, controls, game data,
  diagnostics, multiplayer access, and motion steering. On iPhone/iPad 0.4.9,
  taking a screenshot reasserts the button immediately and again on the next
  main-loop pass if iPadOS temporarily changes the menu presentation state.
- **Player identity:** **Game Data & Saves → Player Identity…** sets the
  online name, manages exact existing Original/Retro Rewind license slots, and
  imports standard `.mii` appearances without replacing game data.
- **Experimental Wii hardware:** direct Wii Remote/Nunchuk pairing is available
  only in the macOS build; the iPhone/iPad entry explains that platform limit.

KartPad's owning layer adds two actions ahead of SunPad's unchanged menu:

- **Multiplayer…** reports connected controllers, stable Player 1–4 assignment,
  and opens controller setup guidance. The first controller takes over Player
  1 from touch; Players 2–4 publish independent retail KPAD channels.
- **Motion Steering…** is default-off and provides recenter, inversion, and
  0.5×/1×/2× sensitivity. Touch can override it, physical controllers take
  priority, and backgrounding clears the live motion state.

The full retail graph boots on iPhone 17 Pro and iPad Pro 13-inch Simulator,
reaches title/menu/live Luigi Circuit, survives background/foreground, and
preserves exact save hashes across relaunch. The original icon catalog, privacy
manifest, opaque fitted-output bands, package boundary, and full 29,065-function
unsigned physical-device build pass. Locally signed builds from that IPA have
also been installed and accepted on physical iPhone and iPad hardware.
Simulator motion sensors are unavailable by design; additional motion tuning,
long-run performance, and audio characterization remain active work rather
than blockers to the completed device acceptance.

## First launch on iPhone or iPad

KartPad does not include Mario Kart Wii and cannot compile game code on-device.
For a locally built development app:

1. Build and locally sign KartPad on the Mac using your private translated
   `RMCP01` graph.
2. Put your supported `RMCP01` revision-0 WBFS/ISO in Files. An already
   extracted `DATA` folder remains supported as a fallback.
3. Launch KartPad and choose the disc image or extracted folder when prompted.
4. Leave the app open while it extracts or copies, validates, protects, stages,
   and activates the data. A successful first import continues into the game
   in the same session.
5. Later, use **••• → Game Data & Saves** to reimport or schedule removal.

The exact iPad-then-iPhone hands-on procedure is in
[`docs/PHYSICAL-ACCEPTANCE.md`](docs/PHYSICAL-ACCEPTANCE.md).

Saves live separately from the extracted game-data tree. Reimport and removal
retain them; uninstalling the app still removes its whole Apple container.

## Mobile screenshots

<table>
  <tr>
    <td width="50%"><img src="docs/artifacts/2026-08-30/g14-full-game-simulator/iphone-live-race-touch.jpeg" alt="KartPad live Luigi Circuit gameplay with the touch overlay on iPhone Simulator"></td>
    <td width="50%"><img src="docs/artifacts/2026-08-30/g14-full-game-simulator/ipad-live-race-touch.jpeg" alt="KartPad live Luigi Circuit gameplay with the touch overlay on iPad Simulator"></td>
  </tr>
  <tr>
    <td align="center"><strong>iPhone retail runtime</strong><br>Metal gameplay with KartPad's touch controls.</td>
    <td align="center"><strong>iPad retail runtime</strong><br>The independent tablet layout scales across the larger safe area.</td>
  </tr>
</table>

These are Simulator development-build captures using game data supplied
privately by the device owner. No game image, extracted data, save, or playable
binary is part of this repository.

## Diagnostics and privacy

Start with the [support guide](docs/SUPPORT.md) for save transfers, aspect modes,
Android graphics/performance comparisons, external displays, and exact log
collection steps. The [bug report form](https://github.com/chrissotraidis/kartpad/issues/new?template=bug_report.yml)
accepts the fields prefilled by the iPhone/iPad and Android report buttons.

On Mac, choose **Help → Save Diagnostics Report…** after a failure or slow
session. The schema-3 report contains bounded build/runtime identifiers,
selected safe settings, storage health, clean-versus-unclean shutdown state,
and capped current/previous log tails. User-directory prefixes and usernames
are redacted. It excludes the disc image, extracted files, generated game
module, saves, and file contents.

On iPhone or iPad, use **••• → Report a Problem…** to create KartPad's bounded
technical report and review it before sharing. Never attach game
data, generated modules, saves, signing material, or a complete app container
to a public report.

## Evidence-first development

KartPad keeps publishable, content-safe evidence under `docs/artifacts/` and
private traces under ignored paths. Every accepted step records the candidate,
procedure, observed result, hashes, limitations, and next gate. The project
does not infer timing, audio quality, touch feel, or stability from source
inspection alone.

Useful starting points:

- [`docs/STATUS.md`](docs/STATUS.md) — current accepted state and open risks.
- [`docs/PRD.md`](docs/PRD.md) — product requirements and release matrix.
- [`docs/PORTABILITY.md`](docs/PORTABILITY.md) — Windows-to-Apple host boundary.
- [`docs/SEMANTICS.md`](docs/SEMANTICS.md) — PPC/AArch64 correctness evidence.
- [`docs/RELEASE-CHECKLIST.md`](docs/RELEASE-CHECKLIST.md) — release gates.

## Frequently asked questions

### Can I download an IPA or playable app?

Yes. `v0.4.11` provides the corrected unsigned iPhone/iPad IPA, which must be re-signed
before installation. The corrected Apple Silicon Mac ZIP is in
[`v0.4.11-macos.1`](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-macos.1).
The corrected experimental Apple TV IPA is in
[`v0.4.11-tvos.1`](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-tvos.1);
older tvOS IPAs should stay offline. Android's APK is in
[`v0.4.10-android.1`](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.10-android.1);
follow [the Android guide](docs/INSTALL_ANDROID.md).
They contain
KartPad's compiled ARM64 translation but no disc image or extracted game assets,
so you must supply your own legally obtained supported game data. The Personal
IPA Builder remains available as a separate local workflow. Follow
[`docs/INSTALL_IPA.md`](docs/INSTALL_IPA.md), and read
[`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md) for the community-release
boundary.

### Does online multiplayer work?

The development build now passes end-to-end login, matchmaking, room formation,
course voting, a two-player race, native results/ratings, and lobby return
between macOS and an iPad Simulator against a compatible isolated WFC server.
Public Retro WFC compatibility, Wiimmfi, physical-device online play, and
external-client interoperability remain separate acceptance gates. As of 6
September 2026, Retro WFC's health endpoint reports its external API healthy
and the public room feed reports active rooms. The earlier maintenance outage
was over at that check. The maintainer subsequently navigated to Friends on
physical iPad build 25; a complete production online race remains unverified.

- [Retro Rewind service notice](https://mkwiiki.org/wiki/Retro_Rewind)
- [Retro WFC status](https://status.rwfc.net/)

### Does KartPad support Retro Rewind?

Yes. The current Mac/iPhone/iPad 0.4.11 and Android 0.4.10-android.1 builds support
Original / Retro Rewind using the separately installed, hash-verified Retro
Rewind 6.12.7 pack. KartPad does not bundle Mario Kart Wii or Retro Rewind content.
The maintainer accepted Retro Rewind launch and menu navigation on physical
iPad build 25. Earlier physical tests covered pack download, verification,
installation, and initial single-player gameplay on the tested pack version.
Complete production-online races remain a separate check.

Before Retro Rewind starts, KartPad checks the official version feed. If Retro
Rewind advances beyond the version compiled into the app, KartPad asks for a
compatible KartPad update instead of launching an outdated online pack.

### Can KartPad set my player name or import a custom Mii?

On iPhone and iPad, use **Game Data & Saves → Player Identity…** to rename the
built-in or an imported Mii. Restarting applies the name to every linked
license while retaining its friend code and progress. Standard 74-byte `.mii`
appearance import remains experimental; KartPad does not reproduce the full Wii
Menu appearance editor.

### Can I connect a Wii Remote and Nunchuk without a DolphinBar?

Experimentally, on macOS only. Enable **Controls → Experimental Wii Remote +
Nunchuk**, pair with the red SYNC button, attach the Nunchuk, and choose the
experimental preset in Controller Settings. This direct Bluetooth path still
needs wider testing with original Wii Remote hardware. It is not available on
iPhone or iPad.

### Are Android or Apple TV supported?

Apple Silicon Mac, iPhone, and iPad are supported. An experimental native Apple
TV tester IPA is included in `v0.4.11-tvos.1`; it has passed build and package
audits but still needs physical Apple TV acceptance before tvOS can be called
supported. See [the tvOS implementation and acceptance plan](docs/TVOS.md).
Android is supported with a full playable ARM64/Vulkan APK in
[`v0.4.10-android.1`](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.10-android.1).
Original with Razer Kishi and Retro Rewind online race play have maintainer
physical testing on Pixel 9 Pro XL. Other GPUs, controllers and sustained
performance need broader testing. See [installation](docs/INSTALL_ANDROID.md)
and [source builds](android/README.md).

### How much storage does KartPad use?

The current app package is about 80 MiB. Extracted game data uses about 2.5
GiB. Keeping the original WBFS/ISO in Files needs additional space, and the
full source build workspace is much larger than the installed app.

### Does this repository include Mario Kart Wii?

No. You must supply your own legally obtained supported disc image. Do not
open issues requesting game data, extracted files, generated modules, or
download links.

### Is KartPad a general Wii emulator?

No. KartPad is a game-specific static-recompilation integration for one pinned
Mario Kart Wii profile. It is not a loader for arbitrary Wii software.

### Is KartPad using Dolphin or streaming from a Mac?

No. It does not run the game through Dolphin and does not stream gameplay from
another computer. WiiCompiled translates the supported game's PowerPC code
ahead of time. KartPad compiles that translated code for ARM64 and supplies the
Apple app, Metal presentation, input, audio, storage, and lifecycle layers.

### Does KartPad use a PowerPC JIT on iPhone or iPad?

No. The mobile app executes a Mac-generated ARM64 translation and does not
download executable code or compile PowerPC code on-device.

### Why is the frame rate slow on first use?

Dawn and Metal still compile pipelines that are absent from the initial cache.
That work can stall guest progress and pressure the audio queue. Cache
coverage, bounded compilation, and sustained frame pacing are active release
gates; a displayed 60 FPS counter in one scene is not treated as acceptance.

### Why are the inherited experimental modes absent?

They targeted Sunshine-specific features: a 90% emulated CPU clock and a
GMSE01 60 FPS patch. Neither changes KartPad's ahead-of-time Mario Kart Wii
runtime, so the misleading no-op rows were removed. Use 1x render resolution
while diagnosing performance; KartPad's actual work is tracked through
frame-time telemetry, real guest-clock cadence, and CPU/GPU profiles.

### Do saves survive an app update or game-data replacement?

The tested in-place paths keep saves separate from game data, and reimport or
scheduled removal preserves them. A clean uninstall, bundle-identifier change,
or incompatible signing change can still remove or disconnect the app
container, so back up before crossing those boundaries.

### Is everything finished?

No. Native macOS gameplay is broad and the accepted mobile IPA runs real
races, but sustained performance, a complete three- and four-player result
path, the eight-hour soak, fresh-clone provisioning, production online
verification on production Retro WFC, complete touch/motion race coverage, and
the full engineering-completion matrix remain open.
General physical-device acceptance is complete on both iPhone and iPad, while
narrower performance, audio, motion, and controller refinements can continue.

## Project map

| Path | Purpose |
|---|---|
| [`docs/INSTALL_IPA.md`](docs/INSTALL_IPA.md) | Download, checksum, re-signing, first-launch import, and update guidance for the public unsigned IPA |
| [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md) | GPLv3 scope, redistribution rights, Corresponding Source, and game-content boundary |
| [`scripts/build-user-ipa.sh`](scripts/build-user-ipa.sh) | Identify a supported image and build a private unsigned IPA with the profile-driven Builder |
| [`scripts/package-public-unsigned-ipa.py`](scripts/package-public-unsigned-ipa.py) | Deterministically package the exact audited public community-preview IPA |
| [`scripts/audit-public-unsigned-ipa.py`](scripts/audit-public-unsigned-ipa.py) | Reject game data, signing residue, private paths, missing notices, malformed provenance, or an incorrect release build |
| [`builder/profiles/`](builder/profiles/) | Versioned container, executable, and static-translation compatibility profiles |
| [`docs/BUILDER.md`](docs/BUILDER.md) | Personal IPA workflow, cache design, compatibility extension, and public-release boundary |
| [`scripts/self-build-macos.sh`](scripts/self-build-macos.sh) | Verify, extract, translate, build, sign, and audit a local macOS app |
| [`scripts/prepare-disc.sh`](scripts/prepare-disc.sh) | Validate and privately extract the supported disc profile |
| [`scripts/translate-base.sh`](scripts/translate-base.sh) | Produce the ignored full ARM64 translation graph |
| [`scripts/build-ios-game-app.sh`](scripts/build-ios-game-app.sh) | Build the full iPhone/iPad Simulator game app |
| [`scripts/build-ios-device-game-app.sh`](scripts/build-ios-device-game-app.sh) | Build and audit the full unsigned physical-iPhone/iPad game app |
| [`scripts/check-ios-device-runtime-host.sh`](scripts/check-ios-device-runtime-host.sh) | Compile the exact UIKit runtime host for physical iOS and reject Simulator-only hooks |
| [`scripts/audit-macos-package.sh`](scripts/audit-macos-package.sh) | Reject malformed or privacy-unsafe Mac packages |
| [`scripts/audit-ios-game-app.sh`](scripts/audit-ios-game-app.sh) | Reject private data, unsafe linkage, and incomplete iOS bundles |
| [`apple/macos/`](apple/macos/) | Native Mac shell, settings, diagnostics, and runtime integration |
| [`apple/ios/`](apple/ios/) | iPhone/iPad lifecycle, import, multiplayer, and motion integration |
| [`apple/third_party/sunpad/`](apple/third_party/sunpad/) | Exact pinned SunPad touch/menu snapshot and provenance |
| [`patches/`](patches/) | Reproducible WiiCompiled/Aurora/Dawn integration changes |
| [`docs/STATUS.md`](docs/STATUS.md) | Accepted evidence, current risks, and honest open work |
| [`docs/PERF.md`](docs/PERF.md) | Performance measurement contract and acceptance gates |
| [`docs/KNOWN-ISSUES.md`](docs/KNOWN-ISSUES.md) | Known limitations and current workarounds |
| [`docs/TECH-DEBT.md`](docs/TECH-DEBT.md) | Maintainer-owned follow-ups and the evidence required before they can ship |
| [`docs/IOS-THREE-DOT-MENU-FIX.md`](docs/IOS-THREE-DOT-MENU-FIX.md) | Reusable UIKit menu appearance, lifecycle repair, and validation checklist |
| [`docs/FUTURE-FEATURES.md`](docs/FUTURE-FEATURES.md) | Researched but deferred product features, beginning with RetroAchievements |
| [`docs/releases/NEXT.md`](docs/releases/NEXT.md) | Living Preview 5 validation and publication record |
| `ref/`, `private/`, `build/` | Ignored reference checkouts, private inputs, and local outputs |

## Research and credits

KartPad builds on WiiCompiled and its Aurora/Dawn runtime, Dolphin-derived
hardware research, SDL, and the wider static-recompilation community. SunPad
is the direct source—not merely a visual inspiration—for the mobile touch
surface and persistent three-dot menu. Exact pins and provenance live in the
repository verification scripts, the SunPad snapshot record, and the project
documentation.

## Legal and provenance

Mario Kart, Wii, Nintendo, and game imagery are owned by their respective
rights holders and are used here only to identify compatibility and document
runtime behavior. KartPad is not affiliated with or endorsed by Nintendo.

KartPad is free software under the **GNU General Public License, version 3**
([`LICENSE`](LICENSE)). This covers KartPad-owned code and all modifications to
WiiCompiled, including the modified runtime and the integrated application as a
combined work where GPLv3 requires. You may use, modify, and redistribute the
GPL-covered software, including commercially, under the GPL without separate
maintainer approval. Community-release policies do not restrict those rights.
See [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md) for the full scope,
Corresponding Source obligations, and separate game-content rights.

Aurora, Dawn, SDL, Dolphin-derived code, Crypto++, Abseil, FreeType, libpng,
and other dependencies retain their
own licenses and notice obligations. The imported SunPad mobile UI snapshot
retains its GPLv3 license, exact upstream revision, hashes, and attribution.
KartPad's original icon provenance is recorded in
[`branding/PROVENANCE.md`](branding/PROVENANCE.md).

## Contributing

The most useful contributions are reproducible reports against an open row in
[`docs/RELEASE-CHECKLIST.md`](docs/RELEASE-CHECKLIST.md), especially cold/warm
performance captures and physical-device touch, motion, controller, audio, and
lifecycle results. Include the exact commit, hardware, OS, settings, procedure,
and observed result. Never attach private game data, generated game code,
saves, credentials, or signing material to an issue or pull request.
