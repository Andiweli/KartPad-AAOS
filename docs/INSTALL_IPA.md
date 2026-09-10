# Install the KartPad unsigned IPA

KartPad `v0.4.10` is an unsigned ARM64 IPA for iPhone and iPad. It is a free
community release, not an App Store or TestFlight build, and it will not
install until it is re-signed with your own Apple identity or compatible
personal sideloading tool.

1. Download `KartPad-v0.4.10-ios-unsigned.ipa` and `SHA256SUMS` from the
   [0.4.10 release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.10).
2. Verify the IPA with `shasum -a 256 -c SHA256SUMS` on a Mac.
3. Re-sign and install it with AltStore Classic plus AltServer or another
   compatible IPA-signing workflow. AltStore PAL cannot import arbitrary
   unsigned IPA files.
4. On first launch, choose your own legally obtained supported PAL `RMCP01`
   revision 0 WBFS/ISO through the native importer.
5. Choose **Mario Kart Wii** for the original game or **Retro Rewind** for the
   optional expanded game. KartPad can download, verify, and install the
   official version-locked Retro Rewind 6.12.7 full pack.

To change an existing online name, open **••• → Game Data & Saves → Player
Identity… → Rename or Delete Licenses…**. Choose the exact Original or Retro
Rewind profile and numbered slot, then choose **Rename License…**. KartPad
preserves that license's friend code, account data, records, and progress.

To remove a duplicate, choose that exact profile and slot, then **Delete
License…**. Read the second confirmation carefully: deleting a license removes
its friend code, account data, records, and progress. Other licenses retain
their slots. Fully close KartPad from the app switcher and reopen it to apply
either operation. Returning to the KartPad menu and resuming does not apply
pending changes. The live save is revalidated and backed up first.

Use **Edit Mii Name…** to rename a Mii and licenses already linked to it. To
create a license, choose **New** inside the game and select your Mii. Use
**Import Mii Appearance…** for a standard 74-byte `.mii` file. **Remove Mii
Appearance…** does not delete a game license and is blocked while the Mii is
still linked to one.

The persistent **•••** button is restored immediately after iPadOS reports a
screenshot if the system temporarily changes its presentation state.
The experimental direct Wii Remote/Nunchuk pairing flow is macOS-only; the IPA
does not claim direct Wii Remote pairing on iPhone or iPad.

If **Import from This Installation's Folder…** cannot see a game image because
the signer created a different app container, KartPad opens the normal Files
picker automatically. Select the visible WBFS/ISO there; the app still validates
the exact supported game before importing it.

The IPA includes KartPad's ARM64 app and ahead-of-time translated executable
module. It does not include a Mario Kart Wii disc image, extracted courses,
textures, audio, saves, signing certificate, or provisioning profile. The app
still requires the supported user-supplied image because those non-executable
game files are imported privately on the device.

The Retro Rewind pack is also not included in the IPA. Its official download is
about 1.72 GiB, and installation needs additional temporary space. KartPad
checks the official version feed before launching Retro Rewind and asks for a
compatible KartPad update if the online-compatible content profile advances.
The accepted physical iPad flow completed the download, verification,
installation, launch, and a playable single-player match.

Retro WFC is active again as of 6 September 2026. Service recovery does not by
itself establish production compatibility for this exact KartPad artifact;
login, matchmaking, a complete race, results, reconnect, and physical-device
acceptance remain separate gates.

Updating in place with the same bundle identifier and signing identity is the
safest way to retain game data and saves. A clean uninstall can remove the app
container, so back up anything important before uninstalling or changing
signing identities.

The Personal IPA Builder remains available for developers and future verified
container or executable profiles. A locally generated personalized IPA is a
separate, unaudited artifact and is not the published release artifact.
