# VoiceInk Local Build

Tracking upstream: `https://github.com/Beingpax/VoiceInk.git` — merged upstream main: **5628765** (2026-10-13, VoiceInk 2.21+; 29 commits since d7b528a).

## Local Patches

The fork preserves local-build patches in its history. Upstream updates are merged into `main`; do not rebase or amend published history. `origin` is `cxrobx/VoiceInk`, and `upstream` is `Beingpax/VoiceInk`.

| File | Change |
|------|--------|
| `VoiceInk/App/Updates/UpdaterViewModel.swift` | Under `LOCAL_BUILD`, never initialize/start Sparkle or enable dashboard-triggered update checks; prevents official releases replacing this local build |
| `VoiceInk/App/MenuBar/MenuBarView.swift` + `VoiceInk/Features/Settings/Views/SettingsView.swift` | Automatic-update toggle and "Check for Updates" buttons wrapped in `#if !LOCAL_BUILD` (manual check would also install the official build) |

That is the whole patch set. On 2026-10-13 (macOS 26.7.1, Xcode 27.0) every toolchain workaround was dropped in favour of upstream: the vendored `LocalPackages/LLMkit`, the stripped `ENABLE_NATIVE_SPEECH_ANALYZER`, the `LocalizedStringResourceCompat.swift` shims, the 14.4 deployment target and its `#available` guards, and the `mlx-swift-lm` pin. They are in history (`backup/pre-merge-20261013`) if an older toolchain ever returns.

**No source edit for the license:** upstream ships a built-in `#if LOCAL_BUILD → .licensed` bypass in `LicenseViewModel.swift`, and `make local` defines `LOCAL_BUILD`. Take upstream's file as-is on every merge. Same for `NativeAppleTranscriptionService.swift` (now at `VoiceInk/Infrastructure/Providers/Transcription/AppleSpeech/`) — upstream guards it properly.

## Pulling Upstream Updates

```bash
cd ~/VoiceInk
git branch backup/pre-merge-$(date +%Y%m%d) HEAD   # recovery point
git fetch upstream --tags
git merge --no-ff upstream/main
```

**Conflict playbook:** take upstream for every file except the three in the patch table, and re-apply the `#if !LOCAL_BUILD` guards there if upstream reshaped the updater code. Then run `git diff upstream/main HEAD --stat` and confirm **only** those three files plus `CLAUDE.md` appear.

Verify the merge, stage only intended files, and create the merge commit. Do not amend published commits or force-push.

## Building & Installing

Builds locally with `make local` (Xcode 27.0; first run needs `xcodebuild -downloadComponent MetalToolchain`, ~840 MB, for mlx-swift's Metal shaders). The old GitHub Actions route (`build/voiceink-macos` branch) was only needed while Xcode 16.2 was installed.

```bash
cd ~/VoiceInk
make local                                    # LOCAL_BUILD + stable signing + ditto → ~/Downloads/VoiceInk.app
# make local logs "Using stable local signing identity" but the ~/Downloads copy comes out ad-hoc (2026-10-13) — re-sign:
codesign --force --deep --options runtime --entitlements VoiceInk/VoiceInk.local.entitlements -s "Apple Development" ~/Downloads/VoiceInk.app
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

Xcode 27.0 on macOS 26.7.1 builds upstream unmodified (verified 2026-10-13).

## External Dependents (don't break)

- **notes4chris** reads the downloaded whisper model file at `~/Library/Application Support/com.prakashjoshipax.VoiceInk/WhisperModels/ggml-large-v3-turbo.bin` — never clean that directory.
