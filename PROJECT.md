# Flashcards — Project Guide

`PROJECT.md` is the technical map of the Flashcards repository. It complements `README.md`, which is user-facing, and `AGENTS.md`, which contains operational rules for coding agents.

This document describes the current v2 architecture on `main`. When documentation and implementation disagree, the current source code, tests, and workflow are the final behavioral truth.

## 1. Product summary

Flashcards is a native, local-first iOS study app focused on fast card creation, simple organization, focused revision, and full ownership of study data.

The product intentionally avoids infrastructure that is unnecessary for a personal study tool:

- no account system
- no backend
- no cloud database
- no in-app runtime network requests
- no analytics or telemetry
- no advertising
- no third-party SDKs
- no Swift package dependencies
- no app entitlements
- no CloudKit synchronization
- JSON export/restore for user-owned data

The optional Create with AI flow is a user-initiated handoff to ChatGPT, Claude, or Gemini: Flashcards creates and copies a prompt, opens the provider through the system URL handler, and later parses JSON that the user explicitly pastes back. The provider's app/site owns its own network access, document upload, account state, and AI processing. Flashcards does not embed an AI model, call an AI API, proxy requests, or upload the user's study documents itself.

The app should feel like an Apple-native utility rather than a cross-platform product ported to iOS.

## 2. Platform and build facts

| Area | Current choice |
| --- | --- |
| Platform | iOS |
| Minimum deployment target | iOS 27.0 |
| Language | Swift 6.0 |
| UI | SwiftUI |
| Persistence | SwiftData |
| Preferences | `UserDefaults` through `AppPreferences` / `AppSettings` |
| Localization | String Catalog + `L10n` helpers |
| Dependencies | None |
| Backend | None |
| In-app runtime network | None |
| AI integration | External user-controlled handoff only |
| CloudKit | Explicitly disabled |
| App target count | 1 |
| Bundle identifier | `com.raton.flashcards` |
| CI / build runner | GitHub Actions on `xcode-27` |
| Release artifact | Unsigned `.ipa`, distributed only through the private builds repository |

`Flashcards.xcodeproj` contains one native application target.

`FlashcardsApp.swift` creates a local SwiftData `ModelContainer` with `Folder`, `Deck`, and `Card`, using a `ModelConfiguration` named `Local` with `cloudKitDatabase: .none`. The app injects `AppSettings`, applies the selected locale, uses the app accent as the SwiftUI tint, and currently forces the interface to dark mode with `.preferredColorScheme(.dark)`.

## 3. Product invariants

### Native first

Prefer Apple APIs and native SwiftUI behavior: navigation stacks, sheets, menus, alerts, confirmation dialogs, pickers, context menus, SF Symbols, native haptics, system typography, and platform materials.

When reproducing an Apple interaction, behavior matters as much as appearance. Dragging, swiping, reordering, transitions, and sheet presentation should preserve spatial continuity.

### Local first

All core workflows must work without a network connection. A feature must not silently introduce a server, API request, remote database, telemetry endpoint, or remote configuration dependency.

Optional external handoffs may open another app/site only after an explicit user action. They must remain nonessential to manual creation, import, study, backup, restore, and all other core local workflows.

### User-owned data

Folders, decks, cards, card order, folder order, study progress, starred state, resumable sessions, pin state, and study history belong to the user. Persistent state should be exportable when it is part of the user's library experience.

### Small architecture

The project intentionally uses direct SwiftUI + SwiftData rather than a large architecture framework. Add helpers and services where they isolate real domain logic, not to satisfy architectural symmetry.

### Compatibility over cleanup

Stored data and backups can outlive a given UI generation. Legacy fields may remain intentionally even when the v2 interface no longer exposes them.

## 4. v2 visual identity

The current v2 visual system is intentionally fixed rather than theme-selectable.

- brand accent: mint `#46D7A7`
- `AppAccent` currently has exactly one case: `.mint`
- roughly 90–95% of the interface should read as black / white / system gray / material
- mint is a selective signature rather than the default color of every action or surface
- primary CTAs, progress, selected states, success, and small brand details are appropriate mint uses
- repeated library icon surfaces are neutral with white symbols
- large study-mode tiles are neutral rather than solid mint
- red is reserved for destructive actions and exact-duplicate warnings
- native alert actions are white, except destructive actions which remain system red
- orange is used for possible-duplicate warnings
- folder cards are neutral system-gray surfaces
- deck accents still resolve to the global mint accent when a semantic accent is requested
- system typography and SF Symbols are preferred
- continuous rounded shapes are used throughout
- Liquid Glass is used selectively for native floating controls
- the app itself currently renders dark-only even though the app icon has appearance-specific variants

`Theme.deckAccent(for:)` currently returns the global accent and does not derive a visible color from a folder. `Theme.iconSurface` and `NeutralIconBadge` provide the shared neutral treatment for repeated folder/deck glyphs.

### Legacy folder color compatibility

`Folder.colorHex` and `FolderAppearance.presetColors` remain in the model/codebase for storage and backup compatibility. The v2 user-facing folder UI does **not** expose per-folder color branding. Do not remove these fields casually; old SwiftData stores and JSON backups may contain them.

## 5. Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── build-ipa.yml
├── CITests/
│   ├── BackupCodecSmoke.swift
│   ├── BulkImportParserSmoke.swift
│   ├── StudySessionSmoke.swift
│   └── TestSessionSmoke.swift
├── Flashcards.xcodeproj/
├── Flashcards/
│   ├── AppIcon.icon/
│   │   ├── Assets/
│   │   │   ├── Back_Card.svg
│   │   │   ├── Front_Card.svg
│   │   │   └── Middle_Card.svg
│   │   └── icon.json
│   ├── Assets.xcassets/
│   ├── Models/
│   │   ├── Card.swift
│   │   ├── Deck.swift
│   │   └── Folder.swift
│   ├── Services/
│   │   ├── BackupModels.swift
│   │   ├── BackupService.swift
│   │   ├── BulkImportParser.swift
│   │   ├── HapticService.swift
│   │   ├── LibraryActions.swift
│   │   ├── StudySessionState.swift
│   │   └── TestSessionState.swift
│   ├── Views/
│   │   ├── Backup/
│   │   │   └── BackupView.swift
│   │   ├── Celebration/
│   │   ├── Import/
│   │   │   └── BulkImportView.swift
│   │   ├── Library/
│   │   │   ├── CardFormView.swift
│   │   │   ├── DeckDetailView.swift
│   │   │   ├── DeckFormView.swift
│   │   │   ├── DeckRow.swift
│   │   │   ├── EditCardsView.swift
│   │   │   ├── FolderDetailView.swift
│   │   │   ├── FolderFormView.swift
│   │   │   └── FolderTile.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   ├── Study/
│   │   │   ├── StudyCardFace.swift
│   │   │   ├── StudySetupView.swift
│   │   │   └── StudyView.swift
│   │   ├── Test/
│   │   │   ├── TestRunView.swift
│   │   │   └── TestSetupView.swift
│   │   └── HomeView.swift
│   ├── AppPreferences.swift
│   ├── AppSettings.swift
│   ├── FlashcardsApp.swift
│   ├── FolderAppearance.swift
│   ├── L10n.swift
│   ├── Localizable.xcstrings
│   ├── StudyAnimationMetrics.swift
│   ├── TestAnimationMetrics.swift
│   ├── Theme.swift
│   └── icon.png
├── AGENTS.md
├── PROJECT.md
├── README.md
└── LICENSE
```

## 6. Source-of-truth hierarchy

Use these files for different kinds of truth:

1. **Current source + tests** — final runtime behavior.
2. **`.github/workflows/build-ipa.yml`** — build, release, and CI contract.
3. **`PROJECT.md`** — architecture, product constraints, data model, and subsystem map.
4. **`AGENTS.md`** — implementation rules for automated coding agents.
5. **`README.md`** — public product documentation and screenshots.

If a README claim conflicts with source, source wins. If a CI grep assertion conflicts with an intentional product redesign, the workflow assertion should be updated atomically with the source rather than preserving obsolete behavior only to satisfy grep.

## 7. Data model

SwiftData is the primary source of truth for the study library.

### `Folder`

Stored fields:

- `id: UUID`
- `name: String`
- `createdAt: Date`
- `iconName: String`
- `colorHex: String`
- `sortOrder: Int`
- `decks: [Deck]`

Relationship behavior:

- `Folder.decks` has a cascade delete rule.
- `Deck.folder` is the inverse.
- The UI can delete a folder while preserving decks by first setting each deck's folder to `nil`, then deleting the folder through `LibraryActions.deleteFolderKeepingDecks`.

Ordering:

- Home folder order is persisted explicitly through `sortOrder`.
- Ties fall back to creation date and then stable identity where needed.
- Do not use relationship array order as user-visible ordering.

Compatibility note:

- `colorHex` is still serialized but is no longer a user-facing v2 brand control.

### `Deck`

Stored fields:

- `id: UUID`
- `name: String`
- `deckDescription: String?`
- `createdAt: Date`
- `updatedAt: Date`
- `lastOpenedAt: Date?`
- `completedStudySessions: Int`
- `activeStudySessionData: Data?`
- `studyHistoryData: Data?`
- `lastStudyActivityAt: Date?`
- `isPinned: Bool`
- `folder: Folder?`
- `cards: [Card]`

Relationship behavior:

- `Deck.cards` has a cascade delete rule.
- `Card.deck` is the inverse.

Usage notes:

- `lastOpenedAt` drives Recent ordering.
- `isPinned` drives the Pinned Home section.
- `activeStudySessionData` stores an encoded `ActiveStudySessionSnapshot` for Resume.
- `lastStudyActivityAt` participates in ordering resumable decks.
- `studyHistoryData` stores encoded study history entries.
- `completedStudySessions` is part of study progress/reset state.
- `deckDescription` exists in the SwiftData model but is not currently surfaced by `DeckFormView`. It is also not currently represented in `BackupDeckDTO`, so do not assume it survives JSON export/import without explicitly extending the backup format.

### `StudyHistoryEntry`

A deck's history is encoded as local JSON data inside `studyHistoryData`.

Each entry stores:

- `id`
- `completedAt`
- mode: `.flashcards` or `.test`
- `itemCount`
- `correctCount`
- `incorrectCount`

`successRate` is computed from `correctCount / itemCount`.

History is intentionally bounded to the five most recent entries per deck.

### `Card`

Stored fields:

- `id: UUID`
- `term: String`
- `definition: String`
- `position: Int`
- `mastered: Bool`
- `timesStudied: Int`
- `timesCorrect: Int`
- `isStarred: Bool`
- `deck: Deck?`

Ordering:

- card order is explicit through `position`
- all card-list operations should sort by `position`
- move/delete operations normalize positions when required

## 8. Preferences and settings

Persistent preferences live in `UserDefaults` through `AppPreferences`. `AppSettings` is an `@Observable`, `@MainActor` wrapper injected into SwiftUI.

### Language

`AppLanguage` supports:

- Automatic
- French (`fr`)
- English (`en`)
- German (`de`)
- Spanish (`es`)

Automatic mode uses the current system locale.

### Current settings toggles

`SettingsView` exposes:

- haptics
- celebration animations
- study history
- Resume Home section
- Recent Home section
- Pinned Home section
- folder-scoped search behavior
- app language
- backup / restore entry point

### Study preferences

The following are also persisted:

- study direction
- shuffle
- starred-only mode

These preferences are reused so repeated sessions do not require full setup every time.

### Accent preference compatibility

`AppPreferences.accentColor` and `AppSettings.accentColor` still exist, but `AppAccent` has only `.mint`. There is no user-facing accent picker in the current UI.

## 9. Localization

The String Catalog source language is French.

Supported app languages:

- French
- English
- German
- Spanish
- Automatic system selection

Localization mechanisms:

- localized SwiftUI string-key initializers
- `LocalizedStringKey`
- `Localizable.xcstrings`
- `L10n.text(...)` for concrete strings
- `L10n.format(...)` for formatted strings
- domain helpers such as `L10n.cards`, `L10n.decks`, and `L10n.questions`

`L10n` resolves the selected language directly from the `settings.language` UserDefaults key. It also contains inline FR/EN/DE/ES translations for duplicate warnings/actions and the external-AI creation flow.

### Important CI constraint

`L10n.swift` is compiled directly by Foundation smoke tests without the whole app target. Keep it Foundation-only: it must not depend on `AppSettings`, SwiftUI, SwiftData models, or other app-only types unless the smoke-test compilation is deliberately updated.

The workflow also requires every String Catalog entry to have an English localization marked `translated`.

## 10. Home architecture

`HomeView` is the root library experience.

The main section order is intentionally:

1. Resume
2. Recent
3. Pinned
4. Folders

Resume, Recent, and Pinned are individually configurable in Settings. Folders remain the permanent primary library section.

### Resume

A deck appears in Resume only when:

- `activeStudySessionData` decodes successfully
- the session belongs to that deck
- the current index is greater than zero
- the current index is still before the end
- all remaining card IDs still exist in the deck

Resumable decks are sorted by `lastStudyActivityAt` descending.

### Recent

Recent is based on `lastOpenedAt`, sorted newest first, and currently shows at most two decks.

### Pinned

Pinned decks are filtered by `isPinned` and sorted by last-opened time, falling back to `updatedAt`.

### Folders

Folders are shown in a two-column `LazyVGrid` with neutral `FolderTile` cards, white SF Symbols on neutral icon surfaces, title, and deck count.

An Unfiled entry appears when one or more decks have `folder == nil`.

### First-use onboarding

When there are no folders and no decks, Home shows a first-deck flow that can:

- create a deck directly, including the same AI/manual creation choice as later decks
- create a folder first, then continue into deck creation
- import cards / backup data

## 11. Folder reordering and drag behavior

Folder drag/reordering has been a regression-sensitive area on iOS 27 and should be treated separately from ordinary library mutations.

### Current implementation

Current `HomeView` uses the classic SwiftUI drag/drop path rather than depending on the newer `reorderable` / `reorderContainer` API for the active UI:

- `draggedFolderID` identifies the active folder
- `onDrag` provides an `NSItemProvider`
- the drag preview explicitly rebuilds a `FolderTile`
- `FolderReorderDropDelegate` receives drop-enter events
- `moveFolderDuringCustomDrag` updates `folderOrderIDs` live
- `finishFolderCustomDrag` persists the final order
- `sortOrder` is written back to every affected `Folder`

### Haptics

Folder reorder haptics are intentionally tied to **visual slot changes**, not just final persistence:

- each tile reports its frame in the named `folder-reorder-grid` coordinate space
- row/column are converted to a two-column visual slot
- a reorder haptic fires when a tile's slot actually changes
- haptics are armed after a short reset delay
- duplicate rapid haptics are coalesced over a very small interval

This separation is intentional: visual movement drives feedback; persistence stores the result.

### Platform note

Recent development found that iOS 27 runtime behavior can affect system drag previews even for older app builds. Do not assume a drag visual regression is necessarily caused by the most recent source change. Validate on the actual runtime before replacing a working strategy.

## 12. Library UI

### Folder detail

`FolderDetailView` displays decks as compact full-width rows rather than a card grid. The same deck visual language is shared with Home/search where appropriate.

Folder pages provide:

- deck list
- deck creation
- scoped search entry
- context actions
- Unfiled support when the folder argument is `nil`

### Deck presentation

Deck rows/tiles use:

- a white deck glyph on a neutral reusable icon surface
- one-line deck title
- card count metadata
- optional folder context
- disclosure affordance

### Context actions

Home and library context menus provide operations such as:

- pin / unpin deck
- edit
- duplicate
- delete

Folder deletion can either preserve decks by moving them to Unfiled or delete the full folder contents.

## 13. Card creation and editing

`DeckFormView` is the public entry point for deck creation/editing.

For an existing deck, it opens the existing editor behavior directly. For a new deck, it coordinates a staged flow:

1. choose the deck name
2. choose **Create with AI — Recommended** or **Create manually**
3. continue into the existing card editor with either empty manual drafts or parsed AI drafts

The manual path deliberately reuses `DeckEditorForm` and the previous card-draft/save behavior rather than introducing a separate persistence path.

`CardFormView` handles adding/editing an individual card.

Shared editor visuals are implemented by `CardEditorSurface` in `Theme.swift`.

Key rules:

- trim whitespace before validation/save
- a card needs both term and definition
- new-deck initial drafts may be added/removed
- incomplete non-empty drafts block save
- duplicate analysis runs before committing relevant card creation/editing

### External AI deck creation

`NewDeckCreationFlow`, `ExternalAIProvider`, `ExternalAIFlashcardPromptBuilder`, and `ExternalAIFlashcardParser` implement the optional provider handoff.

Provider behavior:

- providers are presented in this order: Claude, ChatGPT, Gemini
- the generated prompt is copied to `UIPasteboard` before every provider launch
- provider launch uses stable public HTTPS entry points
- the feature does not depend on undocumented prompt-prefill parameters
- if a provider does not prefill the composer, the user pastes the already-copied prompt manually
- source notes/images/documents are attached inside the provider, not read or uploaded by Flashcards

Return/import behavior:

- the AI prompt requests a strict JSON object with a `flashcards` array
- the response tells the user to wait for generation to finish before copying the JSON block and returning to Kavi
- the parser accepts the expected object, fenced JSON embedded in explanatory text, and a bare top-level array as a defensive fallback
- terms/definitions are trimmed and every imported entry must have both fields
- valid output becomes `[ParsedCard]`
- parsed cards are passed into the same editable new-deck draft UI used by manual creation
- the same `BulkDuplicateDetector` and final SwiftData save path are reused

No AI state is persisted and no AI response is sent anywhere by Flashcards.

`EditCardsView` provides multi-card management including:

- selection
- star / unstar
- delete
- move to another deck
- copy to another deck
- card reordering

`LibraryActions` centralizes reusable mutations and normalizes positions where required.

## 14. Duplicate detection

Duplicate detection is shared through `BulkDuplicateDetector`.

Normalization:

- trim whitespace/newlines
- case-insensitive folding
- diacritic-insensitive folding

Classification:

- **Exact**: normalized term and normalized definition both match a known card
- **Possible**: normalized term matches but definition differs

The detector compares candidates against:

- existing deck cards supplied to the analysis
- candidates already seen earlier in the same batch

Current duplicate handling is used in:

- new-deck card drafts, including external-AI-imported drafts
- individual card creation
- card editing
- bulk import

When editing, the edited card should be excluded from its own comparison set.

UI semantics:

- exact duplicate → red
- possible duplicate → orange
- user can deliberately continue when appropriate

## 15. Bulk Add / Import

`BulkImportView` and `BulkImportParser` implement offline text-to-card import.

Features include:

- direct clipboard paste
- configurable term/definition delimiter
- configurable card delimiter
- custom delimiters
- preview before import
- invalid-record reporting
- ignored-empty-record reporting
- duplicate preview
- skip exact duplicates
- import anyway
- import into an existing deck
- create a new deck from the importer

Parser behavior:

- input is split by the configured card delimiter
- empty records are ignored and counted
- the first term delimiter separates term from definition
- both sides are trimmed
- missing delimiter / empty term / empty definition produce localized invalid-record reasons

`BulkImportParser.swift` also hosts the Foundation-only external-AI provider/prompt/JSON parsing helpers so they can reuse `ParsedCard` and be exercised by the same smoke-test target without introducing another project file or UI dependency.

Everything in both parsing paths runs locally.

## 16. Study flow

Study mode is split between setup/state/rendering:

- `StudySetupView`
- `StudySessionState`
- `StudyView`
- `StudyCardFace`
- `StudyAnimationMetrics`

### Direction

`StudyDirection` supports:

- term → definition
- definition → term
- random per card

### Session options

Current session size choices:

- 10
- 20
- all

Other options:

- shuffle
- starred-only

### Session state

Each study item stores a card snapshot plus whether the card is reversed.

Tracked session state includes:

- current index
- cards seen
- correct answers
- review answers
- completion state
- judgments used for undo/review

Study outcomes are:

- `.knew`
- `.review`

The state can restore the previous card-progress snapshot when undoing.

### Resume

`ActiveStudySessionSnapshot` contains:

- deck ID
- session number
- `StudySessionState`

It is encoded into the deck's `activeStudySessionData` and validated against the deck ID when decoding.

### User-facing behavior

Study supports:

- card flip animation
- swipe/answer judgments
- editing the current deck card in place without leaving or restarting the session
- undo
- progress
- haptics
- mistake review
- resumable sessions
- completion celebration when enabled
- study history recording when enabled

## 17. Test flow

Test mode is split between:

- `TestSetupView`
- `TestQuestionFactory`
- `TestSessionState`
- `TestRunView`
- `TestAnimationMetrics`

Question types:

- multiple choice
- true / false
- written answer

### Question generation

The factory:

- selects cards based on requested count
- respects direction
- optionally shuffles cards/questions
- cycles through enabled question types
- generates up to three unique distractors for multiple choice
- creates true/false propositions from other cards when possible

### Answer normalization

Test answers are normalized case-insensitively, diacritic-insensitively, width-insensitively, and with normalized whitespace before comparison.

### Session behavior

`TestSessionState` tracks:

- current question
- submitted answers
- correct count
- score
- current feedback state

Written answers can be manually overridden to correct when the automatic matcher is too strict. Incorrect questions can be retried through `retryErrors()`.

## 18. Study history and progress

Deck detail shows mastered-card progress with `DeckProgressBar`.

When enabled, completed Flashcards/Test sessions are recorded in each deck's bounded study history.

History can be:

- disabled globally from Settings
- cleared per deck
- deleted entry by entry

The current Test history UI intentionally keeps the summary compact by omitting the redundant leading question-count segment while retaining correctness/score information.

## 19. Search

Search is presented through the native navigation flow rather than as a permanent Home field.

Current scopes support matching data such as:

- folder names
- deck names
- card terms
- card definitions

Global search is opened from Home with folder context visible. Folder search can remain scoped to the current folder depending on the Search setting.

The workflow currently expects `.searchable` to live only in `DeckRow.swift`; this is an implementation/CI contract, not a general architectural rule forever.

## 20. Backup and restore

Backup is a core product invariant.

### Schema

Current envelope:

- `BackupEnvelopeV1`
- `schemaVersion = 1`
- scopes: `.deck` and `.database`
- ISO-8601 date encoding
- pretty-printed, sorted-key JSON

### Exported folder fields

- ID
- name
- creation date
- icon name
- legacy color hex
- sort order

### Exported deck fields

- ID
- name
- created/updated timestamps
- last opened date
- completed study session count
- active study session data
- study history data
- last study activity date
- pin state
- folder ID
- cards

Current caveat: `Deck.deckDescription` is not yet part of `BackupDeckDTO`.

### Exported card fields

- ID
- term
- definition
- position
- mastered state
- studied count
- correct count
- starred state

### Backward-compatible decoding

Additive fields use `decodeIfPresent` + defaults where appropriate. Existing schema-v1 backups without newer optional fields should remain readable.

### Import semantics

Import is a merge/upsert, not a destructive replacement:

- items are matched by stable UUID
- existing matching items are updated
- missing local items are added
- local objects absent from the incoming file are not deleted
- folder/deck/card relationships are reconstructed from IDs
- a missing incoming `lastOpenedAt` does not erase an existing local value
- the `ModelContext` is rolled back if import fails

`BackupView` previews the incoming counts before merge and reports added/updated totals afterward.

## 21. Haptics and celebration

`HapticService` is the centralized haptic entry point.

Current event categories include:

- selection
- reorder
- flip
- correct
- review
- wrong
- completion

The completion effect uses Core Haptics when available and falls back to a sequence of impact generators.

Respect the user's global haptics setting before generating feedback.

Celebration visuals are optional and controlled through Settings.

## 22. App icon pipeline

The repository contains both a modern layered icon and a static fallback/verification path.

### Layered icon

`Flashcards/AppIcon.icon/` is the Icon Composer-compatible bundle.

Current `icon.json`:

- uses `Front_Card.svg` as the front glass group
- uses `Middle_Card.svg` as the rear glass group
- applies per-group scale/translation, glass, blur, shadow, and translucency
- uses an automatic dark base gradient
- has an explicit neutral linear-gradient specialization for Light
- has an explicit Dark specialization using the automatic gradient

`Back_Card.svg` remains in the asset folder even though the current layer graph references `Front_Card.svg` and `Middle_Card.svg`.

Clear/tinted behavior is intentionally left to the platform unless explicit specializations are added.

### Static icon

The project also keeps:

- `Flashcards/icon.png`
- `Flashcards/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

CI requires these 1024×1024 PNGs to be byte-identical and requires the asset catalog to contain exactly the expected universal iOS icon entry.

Do not assume a layered `.icon` edit automatically updates the static PNG path.

## 23. CI smoke tests

`CITests/` contains lightweight Foundation-level smoke/regression harnesses:

- `BulkImportParserSmoke.swift`
- `StudySessionSmoke.swift`
- `TestSessionSmoke.swift`
- `BackupCodecSmoke.swift`

The workflow compiles them directly with `xcrun swiftc -swift-version 6` and only the required source files.

`BulkImportParserSmoke.swift` covers both the configurable plain-text importer and the external-AI JSON parser/prompt/provider helpers, including fenced JSON, punctuation-safe content, invalid/incomplete records, empty results, and provider host invariants.

This is why service files used by these tests should stay deterministic and avoid unnecessary SwiftUI/UIKit/app-model dependencies.

## 24. GitHub Actions pipeline

`.github/workflows/build-ipa.yml` is both a build pipeline and an executable repository contract.

### Every push to `main`

The workflow:

1. checks out full history/tags
2. reads the project version
3. verifies Xcode/Swift/iOS toolchain
4. verifies static app-icon invariants
5. runs offline/single-target audits
6. runs Foundation smoke tests
7. builds the Release app for generic iPhone with signing disabled
8. packages an unsigned IPA
9. authenticates to the private `raaaton/Kavi-builds` repository with `KAVI_BUILDS_TOKEN`
10. creates a normal private GitHub release tagged `vMAJOR.MINOR.PATCH-build.RUN_NUMBER`
11. attaches the versioned asset `Kavi-MAJOR.MINOR.PATCH-build.RUN_NUMBER.ipa`

The public repository receives no IPA release asset and no Actions artifact.

### Manual `workflow_dispatch`

Manual dispatch additionally:

1. computes the next release version
2. updates project marketing/build versions in the checked-out workspace
3. runs a simulator build/launch smoke test on an iPhone 17 Pro simulator
4. packages and publishes a normal versioned release only to the private builds repository
5. commits release metadata back to `main` with `[skip ci]` when changed
6. creates the official public GitHub Release/tag without a binary asset

### Version computation

Repository variables:

- `RELEASE_MAJOR`
- `RELEASE_MINOR`

Behavior:

- missing `RELEASE_MAJOR` falls back to `1`
- both values must be integers
- patch is derived from the highest matching `vMAJOR.MINOR.PATCH` tag
- no matching tag → patch `0`
- otherwise patch increments by one
- marketing version = `MAJOR.MINOR.PATCH`
- build version = `MINOR.PATCH`

Ordinary feature/fix commits should not manually bump release metadata.

## 25. CI audit contract

The workflow contains deliberate text/structure audits to enforce architecture and UI invariants. Important examples include:

- no runtime networking / CloudKit / analytics patterns
- exactly one native target
- iOS 27.0 deployment target
- Swift 6.0
- no Swift packages
- no entitlements
- fixed bundle identifier
- source-language / English localization checks
- Home section order
- recent deck count behavior
- required search placement
- required library actions
- required study/test state APIs
- required reusable controls
- expected form toolbar patterns

These checks can become stale after legitimate redesigns. When source behavior is intentionally changed, update the corresponding CI assertion in the same change instead of inserting dead code or obsolete strings solely to satisfy grep.

See `AGENTS.md` for the current high-risk exact assertions.

## 26. Persistence and model evolution

SwiftData stores real user libraries, so model evolution should be conservative.

For additive stored fields:

- provide a safe default when possible
- keep old stores readable
- avoid destructive changes unless explicitly required
- preserve stable UUIDs and relationships
- update backup DTO/service behavior if the field is meaningful user-owned data
- update smoke tests where useful

For ordering:

- cards → `Card.position`
- folders → `Folder.sortOrder`

Never depend on relationship-array order for user-visible order.

## 27. Service boundaries

Use an existing service when a behavior is reusable and already has a domain boundary.

Current examples:

- library mutations → `LibraryActions`
- backup DTO/codec/merge → `BackupModels`
- SwiftData backup import/export → `BackupService`
- text parsing, duplicate analysis, and external-AI JSON/prompt/provider helpers → `BulkImportParser`
- flashcard session state/persistence → `StudySessionState`
- test generation/state → `TestSessionState`
- haptics → `HapticService`

Do not create a service for trivial state that belongs naturally to one view.

## 28. Development principles

Prefer:

- focused diffs
- native SwiftUI behavior
- small reusable helpers
- explicit persisted ordering
- compatibility-preserving model changes
- centralized localization/pluralization
- domain logic that can be smoke-tested without UI
- real runtime validation for interaction-heavy changes

Avoid:

- third-party dependencies
- in-app runtime network features
- remote state
- speculative architecture layers
- unrelated refactors during a feature fix
- changing working interactions without a concrete reason
- CI-only fake strings/dead code to satisfy an obsolete audit

## 29. Current regression-sensitive areas

Some parts of the app deserve extra care because their behavior depends heavily on iOS runtime rendering/interaction details.

### Folder drag/reorder

The actual feel of the drag preview, finger-following behavior, grid reflow, and post-drop reconciliation cannot be fully validated by compile-only CI. Preserve the current haptic semantics and test on-device/IPA when changing this path.

### App icon appearances

Icon Composer appearance rendering can differ between Light, Dark, Clear, and Tinted system variants. A JSON configuration that looks equivalent structurally may not produce visually identical material/reflection behavior. Keep changes scoped to the requested appearance whenever possible.

### String Catalog / literal UI strings

Some current CI assertions grep exact source literals. Refactors that are semantically harmless can still fail CI. Inspect the workflow before renaming/removing audited strings or helpers.

### External provider handoff

Provider websites/apps can change their URL handling independently of Flashcards. Keep clipboard copy as the reliable path, avoid depending on undocumented query parameters, and manually validate the ChatGPT/Claude/Gemini open-return experience on a real iPhone when this flow changes.

## 30. Definition of project consistency

A repository change is architecturally consistent when:

- the app remains native/local/offline for all core workflows
- optional external handoffs stay explicit and do not become a backend/API dependency
- the data model and backup behavior remain compatible where relevant
- user-visible strings follow localization conventions
- the monochrome-first / selective-mint visual semantics remain coherent
- direct-manipulation behavior remains spatially understandable
- smoke tests cover changed deterministic logic when practical
- CI assertions still describe the intended product
- release/version ownership remains with the workflow
- the final diff contains no unrelated architecture churn
