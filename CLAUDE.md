# VoiceInk Local Build

Tracking upstream: `https://github.com/Beingpax/VoiceInk.git` — merged upstream main: **d7b528a** (2026-09-22, VoiceInk 2.20; 38 commits since 5a6aaf4).

## Local Patches

The fork preserves local-build patches in its history. Upstream updates are merged into `main`; do not rebase or amend published history. `origin` is `cxrobx/VoiceInk`, and `upstream` is `Beingpax/VoiceInk`.

| File | Change |
|------|--------|
| `VoiceInk.xcodeproj/project.pbxproj` | `ENABLE_NATIVE_SPEECH_ANALYZER` removed from all `SWIFT_ACTIVE_COMPILATION_CONDITIONS` lines (macOS 26 speech symbols absent from the 15.2 SDK); LLMkit registered as `XCLocalSwiftPackageReference "LocalPackages/LLMkit"` (product dep points at the local ref — no dangling remote UUID) |
| `.../swiftpm/Package.resolved` | `llmkit` remote pin removed (local packages aren't pinned) |
| `LocalPackages/LLMkit/` | Vendored LLMkit at upstream's pin `7cb532eb0af56b6b4d3c8049c0c0083f1b3cb2d6`; `Sources/` and `Tests/` copied verbatim. Only `Package.swift` differs: `swift-tools-version: 6.0` instead of 6.2. This compatibility setting does not make the app's other dependencies compatible with Xcode 16.2. |
| `VoiceInk/App/Updates/UpdaterViewModel.swift` | Under `LOCAL_BUILD`, never initialize/start Sparkle or enable dashboard-triggered update checks; prevents official releases replacing this local build |
| `VoiceInk/App/MenuBar/MenuBarView.swift` + `VoiceInk/Features/Settings/Views/SettingsView.swift` | Automatic-update toggle and "Check for Updates" buttons wrapped in `#if !LOCAL_BUILD` (manual check would also install the official build) |
| `VoiceInk/Utilities/LocalizedStringResourceCompat.swift` | **New file** (auto-included via the synced root group): `@_disfavoredOverload` shims bridging `help(_:)`/`accessibilityLabel(_:)` from `LocalizedStringResource` through `String(localized:)` — those overloads only exist in the macOS 15.4+ SDK (Xcode 16.3+). Lets upstream callsites compile unmodified; delete once the toolchain moves past 16.2. |
| `project.pbxproj` (deployment target) | App/test targets kept at `MACOSX_DEPLOYMENT_TARGET = 14.4` — upstream raised them to 15.0 in 62a7e70 (2.20) only for the mini-recorder drag fix; this Mac runs macOS 14.5, and a 15.0 build would not launch |
| `VoiceInk/Features/Recording/Views/MiniRecorderView.swift` + `.../Presentation/MiniRecorderPanel.swift` | `WindowDragGesture` / `allowsWindowActivationEvents` (macOS 15) wrapped in `#available`; on 14 the panel falls back to `isMovableByWindowBackground = true` |
| `project.pbxproj` + `Package.resolved` (MLX) | `mlx-swift-lm` pinned to `bd4b7434` (3.31.4) instead of upstream's `cd1ab3dd` (f149f12) |
| `Makefile` | Use upstream signing selection, which now chooses the sole Apple Development identity or accepts `LOCAL_CODESIGN_IDENTITY`; the old extra re-sign block is superseded |
| `LocalBuild.xcconfig` | Upstream ad-hoc default, overridden by `make local` when an Apple Development identity is selected |

**No source edit for the license:** upstream ships a built-in `#if LOCAL_BUILD → .licensed` bypass in `LicenseViewModel.swift`, and `make local` defines `LOCAL_BUILD`. Take upstream's file as-is on every merge. Same for `NativeAppleTranscriptionService.swift` (now at `VoiceInk/Infrastructure/Providers/Transcription/AppleSpeech/`) — upstream guards it properly.

## Pulling Upstream Updates

```bash
cd ~/VoiceInk
git branch backup/pre-merge-$(date +%Y%m%d) HEAD   # recovery point
git fetch upstream --tags
git merge --no-ff upstream/main
```

**Conflict playbook:**
- `LicenseViewModel.swift` — take upstream wholesale (`git checkout upstream/main -- <file>`); the `LOCAL_BUILD` bypass is upstream-native.
- `project.pbxproj` — take upstream as base, then (a) re-strip `ENABLE_NATIVE_SPEECH_ANALYZER` from all `SWIFT_ACTIVE_COMPILATION_CONDITIONS` lines, (b) re-point LLMkit at the local package ref.
- `Package.resolved` — take upstream, then delete the `llmkit` pin block.
- `Makefile` — take upstream; it now implements stable signing directly.
- If upstream moved/renamed a file the patch touches, watch for git rename-detection silently reapplying a stale edit — after resolving the merge, run `git diff upstream/main HEAD --stat` and confirm **only** the patch-set files above (plus `CLAUDE.md`) appear.
- If upstream bumped the LLMkit pin (check `git show upstream/main:VoiceInk.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`), re-vendor: fetch that revision of `Beingpax/LLMkit`, `rm -rf LocalPackages/LLMkit/Sources`, copy the pin's `Sources/` and `Tests/` in, and copy its manifest with only the tools-version changed to 6.0. Compare manifests for new targets or dependencies.

Verify the merge, stage only intended files, and create the merge commit. Do not amend published commits or force-push.

## Building & Installing

**Local Xcode 16.2 can no longer build the app** — `mlx-swift-lm` needs Swift tools 6.1 (`make local` fails at package resolution). Builds run on GitHub Actions: branch `build/voiceink-macos` = `main` + one commit adding `.github/workflows/local-app-build.yml` (macos-15 runner, Xcode 26.3, unsigned Release arm64 with `LocalBuild.xcconfig`, artifact `VoiceInk-arm64`). To build: reset that branch onto `main`, cherry-pick the workflow commit, force-push the branch (it is a build branch, not history), `gh run watch`, `gh run download -n VoiceInk-arm64`, unzip, then re-sign locally with `codesign --force --deep --options runtime --entitlements VoiceInk/VoiceInk.local.entitlements -s "Apple Development"` before installing as below (the `codesign -dvv` check still applies). The `make local` path below applies again once a Swift 6.1+ Xcode is installed.


```bash
cd ~/VoiceInk
make local                                    # LOCAL_BUILD + stable signing + ditto → ~/Downloads/VoiceInk.app
codesign -dvv ~/Downloads/VoiceInk.app 2>&1 | grep -E "Authority|TeamIdentifier"
#   must show "Apple Development: Christopher Robinson" / CCYV5HQZCM — ad-hoc means the re-sign failed (permissions would reset)
pkill VoiceInk
rm -rf /Applications/VoiceInk.app && ditto ~/Downloads/VoiceInk.app /Applications/VoiceInk.app
open /Applications/VoiceInk.app
defaults write com.prakashjoshipax.VoiceInk SUEnableAutomaticChecks -bool false   # belt-and-suspenders vs Sparkle
```

## Permissions (one-time per machine)

The app is signed with the **Apple Development** cert (`CCYV5HQZCM`) — permissions persist across all rebuilds.

If you ever need to reset (e.g. new machine):
```bash
tccutil reset Accessibility com.prakashjoshipax.VoiceInk
tccutil reset ScreenCapture com.prakashjoshipax.VoiceInk
```
Then grant Accessibility and Screen Recording in VoiceInk → Permissions.

## Xcode Version

The previously installed build used **Xcode 16.2** (Swift 6.0.3, macOS 15.2 SDK). Validation on 2026-09-16: the vendored LLMkit compiled and all 4 tests passed. The app build stopped during package resolution because pinned `mlx-swift-lm` requires Swift tools 6.1.0 and installed Xcode provides 6.0.0. Full app validation requires a compatible newer Xcode toolchain; other dependencies may impose additional requirements. Historical compatibility patches remain:
- Remote LLMkit needs a Swift 6.2 toolchain → vendored locally with a 6.0 manifest.
- Native Apple transcription (macOS 26 speech APIs) won't compile against the 15.2 SDK → `ENABLE_NATIVE_SPEECH_ANALYZER` stays stripped.

## External Dependents (don't break)

- **notes4chris** reads the downloaded whisper model file at `~/Library/Application Support/com.prakashjoshipax.VoiceInk/WhisperModels/ggml-large-v3-turbo.bin` — never clean that directory.
