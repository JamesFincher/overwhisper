# AGENTS.md

Repository guidance for Codex and other coding agents working on Overwhisper.

## Repository Authority

The canonical repository for this project is `JamesFincher/overwhisper`.
Use `https://github.com/JamesFincher/overwhisper.git` for fetches, pushes, PRs, releases, and Symphony-created workspaces.
Do not push branches, open PRs, tag releases, or publish release assets against `OverseedAI/overwhisper`.

## Project Overview

Overwhisper is a native macOS 14+ menu bar app for voice transcription. It records audio through `AVAudioEngine`, transcribes with local WhisperKit by default, can fall back to OpenAI Whisper, and inserts text at the current cursor by using the clipboard plus a synthetic paste.

Primary app code lives under `Overwhisper/`:

- `App/`: app entry point, menu bar lifecycle, app state, crash reporting.
- `Audio/`: microphone recording and audio file creation.
- `Hotkey/`: global shortcut handling through HotKey.
- `Transcription/`: shared transcription protocol plus WhisperKit and OpenAI engines.
- `Output/`: text insertion.
- `UI/`: SwiftUI settings, onboarding, overlay, debug audio UI, and menu bar icon.

## Development Commands

Use the repository root for all commands.

```bash
swift build
swift build -c release
swift run Overwhisper
```

The same operations are available through `just`:

```bash
just build
just build-release
just run
just bundle
```

Open the project in Xcode with `open Package.swift` or `open Overwhisper.xcodeproj`.

## Validation

There are currently no XCTest targets. For most code changes, run:

```bash
swift build
```

For release-sensitive or project-file changes, also run:

```bash
swift build -c release
xcodebuild -project Overwhisper.xcodeproj \
  -scheme Overwhisper \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

If validation is blocked by macOS sandbox, signing, or simulator/Xcode cache issues, record the exact command and error in the Linear workpad or PR notes.

## Implementation Notes

- Preserve the menu bar app model. The app should not grow a dock-first workflow unless the issue explicitly asks for it.
- Keep privacy expectations clear: WhisperKit local transcription should remain local; OpenAI API usage is optional and should be explicit in UI and docs.
- `AppState` is the central persisted settings surface via `@AppStorage`. Prefer extending it over adding parallel persistence paths.
- Follow the existing SwiftUI style in `SettingsView`, `OnboardingView`, and overlay components.
- For audio device handling, do not force-set the system default input device. AVAudioEngine should own the default device path; only explicitly set user-selected non-default devices. See `LEARNINGS.md`.
- Treat `project.yml`, `Package.swift`, `Package.resolved`, and `Overwhisper.xcodeproj` as related project metadata. Keep dependency and version changes intentional and consistent.
- Avoid logging secrets, API keys, raw user speech, or full transcription output unless a debug-only path already makes that explicit.

## Release Notes

Release automation is documented in `CLAUDE.md` and `scripts/bump-version.sh`. Do not run release scripts unless the task explicitly asks for a release, production push, or version bump.
