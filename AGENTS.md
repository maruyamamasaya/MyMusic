# MyMusic - Agent Development Guide

## Project Overview

MyMusic is a personal iPhone music player built with Swift and SwiftUI.

The long-term goal is to provide a simple, high-quality local music experience with:

- Local music playback
- FLAC / ALAC / AAC / MP3 support
- Album and artist library
- Playlists
- High-quality audio playback
- Background playback
- Lock screen controls
- AirPods / Control Center controls
- Future streaming support

The application is primarily designed for iPhone.

---

# Architecture

Use the following basic architecture.

View
↓
Store
↓
Service
↓
Model / Apple Framework

Responsibilities must remain separated.

## View

Views are responsible only for presentation and user interaction.

Do not put business logic or audio playback logic directly inside SwiftUI Views.

Examples:

- LibraryView
- SongsView
- AlbumsView
- NowPlayingView
- MiniPlayerView

---

## Store

Stores manage application state and connect Views to Services.

Examples:

- PlayerStore
- LibraryStore
- PlaylistStore
- SettingsStore

Stores may expose state such as:

- currentTrack
- isPlaying
- tracks
- albums
- playlists

Whenever possible, use Apple's Observation framework.

---

## Service

Services perform actual application operations.

Examples:

AudioPlayerService
- Play audio
- Pause
- Seek
- Queue management

MusicLibraryService
- Manage music library
- Scan tracks
- Group albums and artists

MetadataService
- Read audio metadata
- Read artwork
- Read codec / bitrate / sample rate

FileImportService
- Import audio files
- Access Files / iCloud Drive

ArtworkService
- Load and cache album artwork

Do not access these implementation details directly from Views.

---

# Project Structure

Prefer the following structure.

MyMusic/
├── App/
├── Models/
├── Views/
│   ├── Home/
│   ├── Library/
│   ├── Player/
│   ├── Playlist/
│   ├── Search/
│   └── Components/
├── Stores/
├── Services/
├── Utilities/
├── Extensions/
└── Assets.xcassets

Keep files grouped by responsibility.

---

# Swift Rules

Use:

- Swift
- SwiftUI
- Apple standard frameworks whenever possible

Prefer Apple frameworks over unnecessary third-party libraries.

Do not introduce external dependencies unless they provide a clear benefit.

Do not add packages automatically without explaining why they are required.

---

# UI Rules

The primary target is iPhone.

The UI should be:

- Simple
- Modern
- Music-focused
- Spacious
- Easy to operate with one hand

Apple Music may be used as inspiration for interaction patterns, but do not directly copy proprietary visual assets or branding.

Use SwiftUI native components where appropriate.

Support:

- Light Mode
- Dark Mode
- Dynamic Type

Use SF Symbols where appropriate.

Avoid excessive fixed dimensions.

---

# Audio Rules

Audio quality is an important goal of this project.

Do not unnecessarily:

- Re-encode audio
- Transcode local files
- Reduce bitrate
- Change sample rate

Preserve the original audio source whenever practical.

Expected formats include:

- FLAC
- ALAC
- AAC
- MP3
- WAV
- AIFF

Audio playback logic must be isolated in AudioPlayerService.

Views must not directly operate AVFoundation.

---

# Player Architecture

Playback should follow this flow.

PlaybackControlsView
↓
PlayerStore
↓
AudioPlayerService
↓
AVFoundation

Future support may include:

- AVAudioSession
- MPNowPlayingInfoCenter
- MPRemoteCommandCenter
- Background playback
- Lock screen controls
- AirPods controls
- AirPlay

Do not implement these inside SwiftUI Views.

---

# Code Organization

Prefer one responsibility per file.

Avoid extremely large SwiftUI Views.

When a View becomes complex, extract reusable components.

Example:

NowPlayingView
├── AlbumArtworkView
├── TrackInfoView
├── ProgressBarView
└── PlaybackControlsView

Reusable visual components belong in:

Views/Components/

---

# Models

Models should represent application data.

Examples:

Track
Album
Artist
Playlist
AudioFormat

Models should not contain UI logic.

Prefer:

Identifiable
Hashable
Codable

when appropriate.

---

# Git / File Rules

Do not modify:

- Bundle Identifier
- Signing configuration
- Development Team
- Deployment Target
- App Icon settings

unless explicitly requested.

Do not commit:

- .DS_Store
- xcuserdata/
- DerivedData/

Avoid unnecessary changes to:

MyMusic.xcodeproj/project.pbxproj

Respect Xcode File System Synchronized Groups when used.

---

# Build Rules

After making meaningful Swift changes, attempt to build the project.

Use the existing Xcode project and scheme.

Example:

xcodebuild \
-project MyMusic.xcodeproj \
-scheme MyMusic \
-sdk iphonesimulator \
-configuration Debug \
build

If a build fails:

1. Read the build error.
2. Identify the actual cause.
3. Fix the relevant code.
4. Run the build again.

Do not hide or ignore compiler errors.

The expected final state is:

BUILD SUCCEEDED

If the environment cannot run Xcode, explicitly state that build verification was not possible.

---

# Testing

Prefer testable code.

Business logic should not depend directly on SwiftUI.

When adding logic that can reasonably be tested, consider adding tests to:

MyMusicTests/

Do not create meaningless tests purely to increase test count.

---

# Development Approach

Implement features incrementally.

Prefer:

small working feature
↓
build
↓
verify
↓
next feature

instead of implementing many unrelated features at once.

Do not rewrite working architecture unnecessarily.

Before making a large architectural change, inspect the existing implementation first.

---

# Current Development Priority

The core local-player experience reached its completed baseline on 2026-08-14.

The current priority is:

1. Preserve the completed baseline behavior
2. Develop original MyMusic features as small beta increments
3. Build and verify each beta feature independently
4. Document each beta feature's purpose, interaction, and known limitations
5. Promote a beta feature into the baseline only after it is stable

Do not regress the existing library, search, playback, favorites, playlist, or data-management flows while developing beta features.

Streaming and server integration remain future features until explicitly requested.

---

# Future Features

The architecture should not prevent future implementation of:

- Navidrome
- OpenSubsonic
- Personal music server streaming
- Offline downloads
- Wi-Fi / mobile streaming quality settings
- Gapless playback
- Crossfade
- Equalizer
- ReplayGain / volume normalization

Do not implement these unless explicitly requested.

---

# Agent Behavior

Before modifying the project:

1. Inspect the existing code.
2. Understand the current architecture.
3. Preserve working functionality.
4. Make the smallest reasonable change.

When asked to implement a feature:

- Do not silently implement unrelated features.
- Do not unnecessarily redesign existing code.
- Do not create duplicate models or services.
- Reuse existing components when appropriate.
- Keep responsibilities separated.

After completing a task, briefly report:

- Files added
- Files modified
- Architecture changes
- Build result
- Important limitations
