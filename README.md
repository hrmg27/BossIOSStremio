# StremioIOS

Personal iOS Stremio client with an embedded `AVPlayer` and **cross-device
playback-progress sync** (iPhone ⇄ PC ⇄ TV). Not for the App Store. See
`CLAUDE.md` for the full project brief.

## Status

Core slice in place:

- `KeychainStore` — secure `authKey` storage.
- `StremioAPI` — `login`, `datastoreGet`, `datastorePut`, `addonCollectionGet`.
- Models — `LibraryItem` / `LibraryItemState` (field names confirmed against
  `stremio-core`; `timeOffset` and `duration` are milliseconds).
- `LibrarySync` — reads the library, exposes "Continue Watching", writes progress
  back (last-write-wins by `_mtime`).
- Minimal SwiftUI: login → library with a Continue Watching section.

Next: `PlayerView` (AVPlayer + resume + progress write), `AddonClient`,
`DebridResolver`, subtitles.

## Building from Windows

There is no supported way to compile a native iOS app on Windows — Apple's
toolchain is macOS-only. The pipeline here keeps all authoring on Windows and
offloads only the compile step:

1. **Author on Windows** (this repo).
2. **Compile on a cloud Mac.** Push to GitHub → the `Build iOS (unsigned IPA)`
   Action (`.github/workflows/ios-build.yml`) runs `xcodegen generate` +
   `xcodebuild` on a `macos-14` runner and uploads an **unsigned** `.ipa`.
   (Alternatives: Codemagic free tier, or rent a Mac via MacinCloud/MacStadium.)
3. **Install from Windows.** Download the `.ipa`, then use **AltServer** (runs on
   Windows) with **AltStore** on the iPhone to resign it with your free Apple ID.
   AltStore auto-refreshes the 7-day certificate. SideStore is the on-device
   equivalent if you prefer no PC in the loop.

The free Apple ID signs at install time via AltStore, so CI produces an *unsigned*
build and no paid Developer account or signing certs are needed in CI.

### Local build on a Mac (if you get access to one)

```sh
brew install xcodegen
xcodegen generate
open StremioIOS.xcodeproj
```

Bundle ID: `com.hrmg.stremioios` (stable, for consistent AltStore refresh).
