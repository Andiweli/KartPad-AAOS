# First Android release verification

2026-09-07. Release `v0.4.10-android.1`, package `dev.kartpad.android`, code 21.
Source is the reviewed Android branch plus current main and the issue #94
backport (original commit `f4eb89a`, cherry-picked with upstream attribution).
Final merged source commit is recorded in the downloadable `PROVENANCE.json`.

## Physical authority and limits

The owner accepted Preview 15/code 20 on Pixel 9 Pro XL, API 37, ARM64,
4096-byte pages. Original Grand Prix with Yoshi/bike/manual drift worked with
Razer Kishi; touch controls hid when connected. The owner also reported Retro
Rewind 6.12.7 Retro WFC login, worldwide matchmaking and live race play at 3x
over Wi-Fi. These are owner observations, not an automated complete-race/results
trace or comprehensive hardware certification.

Fresh Original save exports across the prior in-place preview update matched
byte-for-byte (2,867,200 bytes); retained Retro content and custom preferences
were preserved. The public release signer differs from that private preview,
so the working phone was not uninstalled, cleared, downgraded or migrated.

Kishi rumble/reconnect, multiple pads, complete lifecycle/motion/audio/thermal
matrices, other phones, long-soak performance and production online results/
reconnect remain open. Existing pre-fix server CSNum history may need service-
admin remediation; no client reset or ban-clear claim is made.

## Final candidate identity

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Private unsigned AAB | 91,220,798 | `dbdf02c1a44c0dbfa03cf69c58cee6f453fbae0b36ee3caaeaddc7cfac01bda2` |
| Public signed APK | 110,327,122 | `f55d9119e56828290c62ec3255a4fd8bad24f9166218c0bc1583051103b09798` |
| Corrected APK libmain.so | — | `e82fae367661d2b08e5356d1b4afb5d5b447925422b0a3092c06210a33adcede` |

Single RSA-4096 release certificate SHA-256:
`c1dbe0a0d72d830a5779476b346a750d0a37515adef992cad2f3863058f7f2f2`.
The private key/password are not repository or release artifacts.
ARM64 only, min API 28, target/compile SDK 36, non-debuggable, shell-profileable,
16 KiB native alignment. No AAB, raw diagnostics, game data, saves, generated
source or private signing material is intended for public upload.

## Verified before publication

- 140 Python tests pass, including the actual old/new SC serial regression with
  ASan/UBSan; the old implementation fails and collides, the corrected one passes.
- 585 translator tests and the PPC semantic differential pass; native Apple
  subsystem smoke, archive path/scan, Android touch/controller probe, bounded
  health history and identity transaction tests pass.
- Pinned references, owned-input identity, patch-hunk validation and repository
  privacy checks pass. One malformed pre-existing Apple-controller patch hunk
  count was corrected without changing its effective source.
- Full fresh Android dual-source preparation passes with the serial correction.
  Its effective files match the incremental build source exactly (excluding
  the patch utility's uncompiled `.orig` backup).
- The actual prepared serial override, compiled with the pinned NDK for ARM64,
  passes numeric identity, guest byte-order and memory-boundary tests on the
  disposable API 36 emulator. Linked `SCGetProductSN_HLE` disassembly confirms
  a byte-reversed four-byte store / `Memory::Write32Slow`, not a string copy.
- Full corrected AAB/APK audits pass; repeated pinned-bundletool derivation is
  byte-identical. Public notice packaging pins the corrected libmain SHA to
  reject stale pre-fix binaries. The other three native libraries remain
  byte-identical to the owner-tested preview.
- The public signer installs on the fresh emulator and updates its earlier
  disposable candidate without clearing data. Both game choices and the real
  image/folder import screen appear. This is package/first-launch evidence,
  not another physical gameplay or online acceptance test.

## Performance observations retained privately

One Retro startup window fell to 19.11 FPS with 1,409 pipelines queued; it
recovered to 59.43 FPS when the queue emptied. Later windows around 50–59 FPS
had no queued pipelines and intermittent presentation delays. Thermal status 2
and battery temperature 42.3 C were observed. The 30-second user-cycle profile
contained 19,227 samples, none lost. Startup compilation is a strong correlate;
warm CPU/presentation/thermal effects and network latency remain distinct,
unresolved questions. Raw profiles and logs stay ignored and local.

Publication/anonymous-download verification is recorded separately after the
hosted bytes have actually been checked. This file alone does not claim upload.
