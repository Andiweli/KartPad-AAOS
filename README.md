# KartPad AAOS — Mario Kart Wii for Android & Android Automotive

**KartPad AAOS is an Android and Android Automotive OS (AAOS) port of Mario Kart Wii, with optional Retro Rewind support, native ARM64 execution and Vulkan graphics.** This fork focuses on Android handhelds and automotive infotainment hardware, with particular attention to CPU performance and playable frame rates on Qualcomm SA8155P-based systems.

Maintained by [Andiweli](https://github.com/Andiweli), the project builds on [KartPad by chrissotraidis](https://github.com/chrissotraidis/kartpad) and [WiiCompiled](https://github.com/patchzyy/Wiicompiled).

**Your own supported Mario Kart Wii game image is required. No game image or extracted Nintendo assets are included.**

[Getting started](#getting-started) · [AAOS optimizations](#android-automotive-performance-optimizations) · [Building](#building-for-android-and-aaos) · [Report an issue](https://github.com/Andiweli/kartpad-aaos/issues) · [License](#credits-and-license)

## What is KartPad AAOS?

KartPad runs a statically recompiled Mario Kart Wii runtime directly on an ARM64 Android device. WiiCompiled translates the supported game's PowerPC code ahead of time; the native runtime provides graphics, audio, input, storage and lifecycle handling.

Gameplay runs locally, without streaming from another computer. This is a game-specific port, not a general-purpose loader for arbitrary Wii games. Its compatibility runtime draws on Dolphin-derived components and research.

The two target environments are:

- **Android:** compatible phones, tablets and Android gaming handhelds.
- **Android Automotive OS (AAOS):** compatible vehicle infotainment systems running Android directly.

AAOS is different from Android Auto phone projection. Installing this app on a phone does not make it available through Android Auto. In a vehicle, play only while parked.

## Features

- **Original Mario Kart Wii and optional Retro Rewind** through the KartPad launcher.
- **Native ARM64 runtime** with **Vulkan rendering**.
- **Physical gamepad support** for controller-based racing and menu navigation.
- **Android touch controls**, including adjustable layouts and automatic hiding when a supported controller is connected.
- **Game-image import** with checks for the supported game identity and revision.
- **Retro Rewind installation** with download verification and matching runtime/content checks.
- **Render-resolution controls** for balancing image quality and performance.
- **Save export/import and local diagnostics** through the in-app menus, with availability depending on the installed build.

## Android Automotive performance optimizations

This fork's AAOS development focuses on reducing native CPU overhead and making better use of automotive hardware:

- Recompiled native ARM64 libraries.
- Native thread-local storage (TLS) optimizations.
- Improvements to floating-point processing in the translated runtime.
- CPU affinity adjustments to make better use of high-performance cores.
- Additional **0.75×** and **0.5×** rendering options in the customized build.

The maintainer reports approximately **50–60 FPS in tested gameplay on an SA8155P-equipped AAOS vehicle** after these optimizations. This is a device- and build-specific observation, not a guaranteed frame rate across all tracks, devices or sessions.

Start at **1× Native**. If performance is insufficient, compare **0.75×** and **0.5×** on the same track. Lower resolution reduces GPU work, but CPU-limited scenes may see little improvement; the lowest setting is not necessarily the fastest in practice.

## Requirements

| Requirement | Details |
| --- | --- |
| Architecture | ARM64 / `arm64-v8a` |
| Graphics | A working Vulkan driver |
| Android version | Android 10 / API 29 or newer for the customized port described here; the checked-in base Android module currently declares API 28 |
| Automotive devices | AAOS with support for installing and running compatible games |
| Game data | Your own supported PAL / European **`RMCP01`, revision 0** WBFS or ISO |
| Controls | A compatible gamepad is recommended, especially on AAOS |
| Storage | Several GB of free space for extraction, temporary files and optional Retro Rewind content |

A matching filename or extension is not enough: the game image must pass the supported profile's validation. Other regions and revisions are not interchangeable.

## Getting started

1. Install an Android or Automotive package built specifically for this fork and your device. Check this repository's [Releases page](https://github.com/Andiweli/kartpad-aaos/releases) for published packages; upstream KartPad packages do not establish that this fork's AAOS changes are included.
2. Open the app and import your supported Mario Kart Wii WBFS/ISO through the system file picker.
3. Allow validation and extraction to finish. Keep a separate backup of your source image.
4. Choose **Mario Kart Wii**, or select **Retro Rewind** and complete its additional content installation.
5. Connect your controller and start with **1× Native** render resolution.
6. Use the **three-dot menu** to access the display, controls, save-management and diagnostic options available in your build.

Retro Rewind requires content matching the compiled runtime profile. If the app requests a compatible update, update the app before using a newer pack.

### Updates and saves

Install updates over the existing app using the same package identity and signing key. Export your saves before updating, and select the correct game profile where offered. Save exports do not necessarily include preferences, Mii data or downloaded content.

Do not uninstall or clear app storage as a routine update step.

## Display and fullscreen on AAOS

Render resolution controls the game's internal image size. It does not change the display area granted to the app by the vehicle system.

System bars, reserved screen areas and manufacturer overlays can limit fullscreen presentation. A fullscreen or fill-screen setting cannot guarantee that every vehicle display becomes completely borderless. When reporting borders or unused areas, include a screenshot, the aspect setting and the device's usable app resolution.

## Building for Android and AAOS

The repository contains the Android application, native runtime integration, translation tooling and reproducible patches.

| Path | Purpose |
| --- | --- |
| [`android/`](android/) | Android Gradle project and application code |
| [`android/app/build.gradle.kts`](android/app/build.gradle.kts) | SDK, ARM64, version and native-build configuration |
| [`runtime/`](runtime/) | Runtime integration and compatibility code |
| [`patches/`](patches/) | Runtime and dependency patches |
| [`builder/profiles/`](builder/profiles/) | Supported game and translation profiles |
| [`scripts/build-android-game-app.sh`](scripts/build-android-game-app.sh) | Full Android game-app build entry point |

**A fresh checkout is not a self-contained playable Android Studio project.** The full game build requires the privately generated translation graph, prepared native dependencies and matching runtime resources. Without the game-runtime inputs, the base Android project uses fixture mode.

The checked-in Android configuration uses SDK 36, Build Tools 36.0.0, NDK 29.0.14206865, CMake 3.31.6 and Java 17. It currently retains the base package `dev.kartpad.android` and does not define separate Android/Automotive product flavors. Separately prepared AAOS packages may therefore differ from this source configuration.

Keep game images, extracted assets, generated game code and signing keys outside the public repository.

## Compatibility and known limits

- Performance depends on the CPU, Vulkan driver, cooling, track and runtime build.
- First-use shader and pipeline compilation can cause temporary stutters.
- Controller behavior and fullscreen presentation need testing on each device.
- Retro Rewind online play depends on matching content and service compatibility. Upstream online test results do not certify every Android or AAOS build of this fork.
- Compatibility with one AAOS vehicle does not imply availability on every vehicle or app store.

### Report a problem

[Open an issue in this repository](https://github.com/Andiweli/kartpad-aaos/issues) and include:

- App version and whether you use the Android or AAOS build.
- Device or vehicle model, Android version, CPU and GPU if known.
- Game mode, track, render resolution and aspect setting.
- Controller model and steps to reproduce the issue.
- Whether the problem occurs on a cold start, after repeated races or after resuming.
- Relevant diagnostic excerpts or screenshots.

Review logs before posting. Do not upload game data, saves, personal identifiers or signing material.

## Credits and license

- **Andiweli:** Android/AAOS fork and automotive-focused adaptations.
- **[chrissotraidis / KartPad](https://github.com/chrissotraidis/kartpad):** upstream application and runtime integration.
- **[WiiCompiled](https://github.com/patchzyy/Wiicompiled):** static recompilation technology.
- **Aurora, Dawn, SDL and Dolphin contributors:** rendering, platform support and compatibility foundations.
- **SunPad contributors:** the upstream mobile touch interface and persistent three-dot menu.
- **Retro Rewind contributors:** the optional mod and its associated services.

KartPad is licensed under the **GNU General Public License, version 3**. See [`LICENSE`](LICENSE) and [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md) for the applicable terms, source obligations and separate game-content rights. Third-party components retain their respective licenses and attribution requirements.

Mario Kart, Wii and Nintendo are trademarks of their respective owners. This is an unofficial community project and is not affiliated with or endorsed by Nintendo. The software license does not grant rights to distribute Nintendo game content.
