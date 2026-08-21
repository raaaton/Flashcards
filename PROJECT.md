# Flashcards — Project Guide

This document is the technical map of the Flashcards repository. It complements `README.md`: the README explains the product to users, while this file explains how the application is structured and which constraints should guide development.

## Product

Flashcards is a native iOS flashcards application focused on fast card creation, distraction-free study, and complete local ownership of user data.

The product deliberately stays small and native:

- no account
- no backend
- no analytics or tracking
- no advertising
- no runtime network requests
- no third-party SDKs
- no package dependencies
- JSON backup and restore for user-owned data

The app is designed around Apple platform conventions rather than a custom cross-platform design system.

## Platform and stack

| Area | Choice |
| --- | --- |
| Platform | iOS |
| Minimum OS | iOS 27.0 |
| Language | Swift 6 |
| UI | SwiftUI |
| Persistence | SwiftData |
| Localization | String Catalog + `L10n` helpers |
| Dependencies | None |
| Backend | None |
| Network | None at runtime |
| CI / release | GitHub Actions + Xcode 27 |

`Flashcards.xcodeproj` contains one native app target.

## Core principles

### Native first

Prefer Apple APIs and native SwiftUI interactions. Use system navigation, sheets, menus, alerts, pickers, SF Symbols, haptics, drag and drop, typography, and Liquid Glass where appropriate.

### Local first

Core functionality must keep working offline. Features should not introduce a server dependency, remote database, analytics endpoint, telemetry service, or hidden network requirement.

### User-owned data

Folders, decks, cards, progress, active sessions, history, ordering, and other persistent state belong to the user and must remain exportable through the JSON backup system.

### Fast interaction

Creating, importing, reorganizing, and studying cards should remain low-friction. Prefer direct manipulation and immediate feedback over extra configuration screens.

### Small architecture

Do not add architectural frameworks for problems that can be solved clearly with SwiftUI, SwiftData, and small focused services.

## Repository layout

```text
.
├── .github/
│   └── workflows/
├── CITests/
├── Flashcards.xcodeproj/
├── Flashcards/
│   ├── Models/
│   ├── Services/
│   ├── Views/
│   │   ├── Backup/
│   │   ├── Import/
│   │   ├── Library/
│   │   ├── Settings/
│   │   ├── Study/
│   │   └── Test/
│   ├── Assets.xcassets/
│   ├── AppPreferences.swift
│   ├── AppSettings.swift
│   ├── FlashcardsApp.swift
│   ├── FolderAppearance.swift
│   ├── L10n.swift
│   ├── Localizable.xcstrings
│   └── Theme.swift
├── README.md
└── LICENSE
```

## Data model

SwiftData is the source of truth for the library.

### `Folder`

A folder owns zero or more decks and stores:

- stable UUID
- name
- creation date
- SF Symbol name
- color hex value
- persistent `sortOrder` used by Home drag-and-drop reordering

Deleting a folder can either cascade to its decks or, through library actions, preserve the decks by moving them to Unfiled.

### `Deck`

A deck stores:

- stable UUID
- name
- timestamps (`createdAt`, `updatedAt`, optional `lastOpenedAt`)
- optional folder relationship
- cards
- pin state
- completed study session count
- resumable study session data
- local study history data
- last study activity timestamp

Study history is encoded locally and intentionally bounded to recent entries.

### `Card`

A card stores:

- stable UUID
- term
- definition
- explicit position inside its deck
- mastered state
- study/correct counters
- starred state
- optional deck relationship

Do not rely on relationship array order for cards; use `position`.

## Main UI domains

### Home

`HomeView` is the entry point for the library. It contains:

- first-use empty-library onboarding
- resumable sessions
- recent decks
- pinned decks
- folder grid
- persistent folder drag-and-drop ordering
- Unfiled access
- global search
- creation actions

Folder reordering is a direct-manipulation interaction: the dragged folder leaves a visual slot while the surrounding grid reflows, and the resulting `sortOrder` is persisted.

### Library

`Views/Library` contains creation/editing and library-detail flows for folders, decks, and cards.

Important behaviors include:

- folder colors and SF Symbols
- contextual deck accent derived from the folder
- gray visual identity for Unfiled, while primary form controls can continue using the global blue accent
- individual and bulk card creation
- card movement/copying between decks
- duplicate detection

### Import

`Views/Import` handles fast plain-text card import and parsing. It is separate from database backup/restore.

Bulk card import supports configurable separators, preview, duplicate handling, and direct paste workflows.

### Backup

`Views/Backup` plus `BackupModels` / `BackupService` implement JSON export and restore.

Backup compatibility is an important invariant. New optional or additive fields must decode older backups safely. Model state that affects the user's library experience — including ordering — should be represented in backups when appropriate.

### Study

The study flow supports direction choice, shuffle, starred-only sessions, session sizing, swipe judgments, undo, resume, mistake review, progress tracking, haptics, and completion feedback.

### Test

The test flow derives questions from the same cards and supports multiple choice, true/false, and written answers while reusing relevant session preferences.

## Styling and interaction

`Theme.swift` contains shared visual helpers and reusable controls. `FolderAppearance.swift` owns folder icons and preset colors.

Design expectations:

- dark interface
- system typography
- SF Symbols
- native SwiftUI controls
- Liquid Glass where it fits the platform
- contextual folder accents
- semantic green/red feedback
- subtle, responsive haptics
- animations should communicate state changes rather than decorate them

When reproducing an Apple interaction, match the behavior as well as the appearance. Direct-manipulation interactions should preserve spatial continuity and avoid visual duplication or abrupt pop-outs.

## Localization

The app currently supports French, English, German, and Spanish.

User-facing strings should use the existing localization system where practical:

- `Localizable.xcstrings`
- `LocalizedStringKey` / localized SwiftUI initializers
- `L10n.text`, `L10n.format`, and domain helpers when a concrete `String` is needed

Pluralization/formatting helpers should remain centralized instead of being reimplemented in individual views.

## Persistence and migrations

Because SwiftData stores real user libraries, model evolution should be conservative.

For additive model changes:

- provide a sensible default when possible
- keep existing stored data readable
- avoid destructive migrations unless explicitly required
- preserve stable IDs and relationships
- update backup DTOs/services when the field is part of user-owned state
- make older JSON backups decode safely with defaults

Ordering should use explicit persisted fields (`Card.position`, `Folder.sortOrder`) rather than implicit array order.

## Services

Keep non-trivial reusable domain logic out of large views when it has a clear service boundary.

Examples include:

- `LibraryActions` for library mutations
- backup codec/import/export services
- bulk import parsing and duplicate detection
- study session persistence/state
- haptics

Services should remain small and deterministic where possible.

## CI and releases

`.github/workflows/build-ipa.yml` is the source of truth for builds when development occurs outside macOS.

The workflow performs project audits, build checks, simulator validation, test harnesses, IPA packaging, and release-related tasks.

A normal push to `main` produces/updates development build outputs. A manual workflow dispatch is used for versioned releases and computes the next release version from repository configuration/tags.

Do not manually bump the Xcode marketing/build version, release tag, or README development IPA link as part of an ordinary feature/fix unless the release workflow itself is being changed.

## CI tests

`CITests/` contains lightweight smoke/regression harnesses for logic that should remain testable without depending on a full UI interaction.

When changing backup formats, parsers, persistence behavior, or similarly testable logic, update/add a CI test when useful.

## Development style

Prefer:

- focused changes
- small helpers over duplicated logic
- explicit persistent ordering
- native SwiftUI behavior
- backward-compatible data changes
- clear names over comments that restate code
- one logical commit per user-visible change when practical

Avoid:

- third-party dependencies
- network features
- unnecessary abstractions
- speculative refactors unrelated to the requested feature
- rewriting established interactions when a smaller native fix preserves working behavior

## Source-of-truth documents

- `README.md`: public product/readme documentation
- `PROJECT.md`: architecture, constraints, and project map
- `AGENTS.md`: repository instructions for coding agents
- `.github/workflows/build-ipa.yml`: build/release/CI contract
- source code and tests: final behavioral truth
