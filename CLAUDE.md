# VoiceInk Local Build

Tracking upstream: `https://github.com/Beingpax/VoiceInk.git` — current base: **v2.0**.

## Local Patches

One commit on top of `origin/main` carries the entire patch set. Keep it that way: after any post-rebase fix, `git add -A && git commit --amend --no-edit`.

| File | Change |
|------|--------|
| `VoiceInk.xcodeproj/project.pbxproj` | `ENABLE_NATIVE_SPEECH_ANALYZER` removed from all 4 `SWIFT_ACTIVE_COMPILATION_CONDITIONS` lines (macOS 26 speech symbols absent from the 15.2 SDK); LLMkit registered as `XCLocalSwiftPackageReference "LocalPackages/LLMkit"` (product dep points at the local ref — no dangling remote UUID) |
| `.../swiftpm/Package.resolved` | `llmkit` remote pin removed (local packages aren't pinned) |
| `LocalPackages/LLMkit/` | Vendored LLMkit at upstream v2.0's pin (`bbfbf5c`), `Sources/` copied verbatim; only `Package.swift` differs — `swift-tools-version: 6.0` instead of 6.2 (Xcode 16.2 can't parse 6.2 manifests). Timeout mapping, `extraBody`, and Speechmatics batch+streaming are all upstream at this pin — no hand tweaks remain. |
| `VoiceInk/VoiceInk.swift` | Sparkle guard: `UpdaterViewModel.init` constructs with `startingUpdater: false` under `#if LOCAL_BUILD` — an official signed release would replace this license-bypassed build and re-enable the trial |
| `VoiceInk/Views/MenuBarView.swift` + `VoiceInk/Views/Settings/SettingsView.swift` | "Check for Updates" buttons wrapped in `#if !LOCAL_BUILD` (manual check would also install the official build) |
| `VoiceInk/Utilities/LocalizedStringResourceCompat.swift` | **New file** (auto-included via the synced root group): `@_disfavoredOverload` shims bridging `help(_:)`/`accessibilityLabel(_:)` from `LocalizedStringResource` through `String(localized:)` — those overloads only exist in the macOS 15.4+ SDK (Xcode 16.3+). Lets upstream callsites compile unmodified; delete once the toolchain moves past 16.2. |
| `Makefile` | Post-build re-sign step using `Apple Development` cert for stable TCC identity (uses upstream's deterministic `.local-build` app path) |
| `LocalBuild.xcconfig` | `CODE_SIGN_IDENTITY = -` (ad-hoc for SPM packages; main app re-signed after build) |

**No source edit for the license:** upstream ships a built-in `#if LOCAL_BUILD → .licensed` bypass in `LicenseViewModel.swift`, and `make local` defines `LOCAL_BUILD`. Take upstream's file as-is on every merge. Same for `NativeAppleTranscriptionService.swift` (now at `VoiceInk/Transcription/Native/`) — upstream guards it properly.

## Pulling Upstream Updates

```bash
cd ~/VoiceInk
git branch backup/pre-merge-$(date +%Y%m%d) HEAD   # recovery point
git fetch origin --tags
git rebase origin/main
```

**Conflict playbook:**
- `LicenseViewModel.swift` — take upstream wholesale (`git checkout origin/main -- <file>`); the `LOCAL_BUILD` bypass is upstream-native.
- `project.pbxproj` — take upstream as base, then (a) re-strip `ENABLE_NATIVE_SPEECH_ANALYZER` from all `SWIFT_ACTIVE_COMPILATION_CONDITIONS` lines, (b) re-point LLMkit at the local package ref.
- `Package.resolved` — take upstream, then delete the `llmkit` pin block.
- `Makefile` — take upstream, re-add the 4-line re-sign block after the APP_PATH check.
- If upstream moved/renamed a file the patch touches, watch for git rename-detection silently reapplying a stale edit — after the rebase, run `git diff origin/main HEAD --stat` and confirm **only** the patch-set files above (plus `CLAUDE.md`) appear.
- If upstream bumped the LLMkit pin (check `git show origin/main:VoiceInk.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`), re-vendor: fetch that revision of `Beingpax/LLMkit`, `rm -rf LocalPackages/LLMkit/Sources`, copy the pin's `Sources/` in, keep the 6.0 `Package.swift` (compare manifests first — they've been identical except the tools-version line).

Then fold everything back into the single patch: `git add -A && git commit --amend --no-edit`.

## Building & Installing

```bash
cd ~/VoiceInk
make local                                    # LOCAL_BUILD + re-sign + ditto → ~/Downloads/VoiceInk.app
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

Built with **Xcode 16.2** (Swift 6.0.3, macOS 15.2 SDK — capped by macOS 14.5). Two hard constraints drive the patch set:
- Remote LLMkit needs a Swift 6.2 toolchain → vendored locally with a 6.0 manifest.
- Native Apple transcription (macOS 26 speech APIs) won't compile against the 15.2 SDK → `ENABLE_NATIVE_SPEECH_ANALYZER` stays stripped.

## External Dependents (don't break)

- **notes4chris** reads the downloaded whisper model file at `~/Library/Application Support/com.prakashjoshipax.VoiceInk/WhisperModels/ggml-large-v3-turbo.bin` — never clean that directory.
