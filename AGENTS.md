# AGENTS.md

Instructions for coding agents working in the Flashcards repository.

Read this file together with `PROJECT.md` before making non-trivial changes. `README.md` is public-facing documentation; `PROJECT.md` is the architecture/product map; this file defines how automated coding work should be performed safely.

When documentation and current source disagree, inspect the source, tests, and workflow before acting. Do not guess from stale context.

## 1. Non-negotiable repository invariants

Preserve these unless the user explicitly asks to change them:

1. Native iOS application.
2. Swift 6.0.
3. SwiftUI UI.
4. SwiftData persistence.
5. Minimum deployment target iOS 26.0.
6. One native app target.
7. Bundle identifier `com.raton.flashcards`.
8. No third-party dependencies.
9. No Swift packages.
10. No backend.
11. No runtime network requests.
12. No CloudKit sync.
13. No analytics / telemetry / advertising.
14. No entitlements.
15. User study data stays local unless explicitly exported.
16. JSON backup/restore remains a core product feature.
17. Prefer Apple-native UI/interaction patterns.
18. Keep the codebase small and understandable.
19. Preserve backward compatibility for stored data where practical.
20. Do not weaken privacy/offline guarantees as a shortcut for a feature.

Do not solve a local UI problem by introducing a package, framework, server, SDK, or remote API unless the user explicitly requests that architectural change.

## 2. Required read-before-edit workflow

Before editing:

- fetch the current `main` head
- fetch every file you intend to modify
- inspect directly related helpers/services/models
- inspect `PROJECT.md` for subsystem constraints
- inspect `.github/workflows/build-ipa.yml` when a change might affect audited source strings, architecture, localization, build settings, release behavior, or project structure
- inspect relevant `CITests/` files when touching deterministic domain logic

Do not assume a file still looks like it did in an earlier conversation or commit.

If the user mentions behavior that previously worked, inspect recent commit history before replacing the implementation. A runtime regression can mimic a source regression.

## 3. Scope discipline

Treat the requested behavior as the scope boundary.

Allowed incidental changes:

- compilation fixes caused by the requested change
- directly adjacent consistency fixes
- localization required by the feature
- backup/persistence updates required by the feature
- CI assertion updates required because an intentional source behavior changed
- smoke-test updates for modified deterministic logic

Avoid:

- unrelated refactors
- broad renames
- architecture rewrites without need
- redesigning already-approved UI while fixing another issue
- deleting legacy compatibility fields merely because they look unused
- “cleanup” commits mixed into a focused user request

When the current behavior is correct except for one issue, prefer a targeted fix.

## 4. Current visual/design contract

The v2 design language is intentionally fixed.

### Brand

- accent: mint `#46D7A7`
- `AppAccent` currently contains only `.mint`
- black / white / system grays structure the UI
- red: destructive actions + exact duplicate warnings
- orange: possible duplicate warnings
- folder cards: neutral surfaces
- folder icon circles: mint
- deck accents: global mint

There is no current user-facing accent/theme picker.

### Native style

Prefer:

- system typography
- SF Symbols
- native navigation
- native sheets/forms/menus/alerts/confirmation dialogs
- native context menus
- continuous rounded rectangles
- system materials
- Liquid Glass where already appropriate
- existing `Theme` helpers

Do not invent a parallel design system for one screen.

### Dark interface

`FlashcardsApp` currently forces `.preferredColorScheme(.dark)`. Do not infer app UI appearance behavior from the app-icon Light/Dark variants; they are separate systems.

## 5. Legacy fields that must not be casually removed

### `Folder.colorHex`

The v2 UI no longer exposes per-folder colors, but `Folder.colorHex`, `FolderAppearance.presetColors`, and backup serialization remain for compatibility.

Do not remove or repurpose them without an explicit migration/backward-compatibility plan.

### Accent preference storage

`AppPreferences.accentColor` and `AppSettings.accentColor` still exist even though `AppAccent` has only `.mint`.

Do not add a picker simply because the preference exists. Do not remove the storage path casually if it would create compatibility churn.

### `Deck.deckDescription`

`Deck` still contains `deckDescription`, but current `DeckFormView` does not expose it and current `BackupDeckDTO` does not serialize it.

Do not assume it is currently a supported backup field. If a task makes descriptions user-facing, update backup behavior deliberately.

## 6. Swift / SwiftUI style

Prefer idiomatic modern Swift and SwiftUI.

- Use value-driven state.
- Keep UI state close to the view when it is truly view-specific.
- Extract helpers when they isolate non-trivial logic or real duplication.
- Reuse existing models/services/components before creating new equivalents.
- Use `@Observable` / `@Bindable` consistently with the existing settings architecture.
- Keep main-thread UI/domain mutations `@MainActor` where appropriate.
- Use system colors or `Theme` semantic helpers.
- Use SF Symbols rather than shipping decorative custom icons unless the task explicitly requires artwork.
- Use `HapticService` rather than creating ad-hoc generators throughout views.
- Keep animations intentional, short, and state-driven.

Avoid comments that merely restate code. Comments are valuable for platform quirks, compatibility constraints, non-obvious timing decisions, and invariants that a future maintainer might otherwise “simplify” incorrectly.

## 7. SwiftData model rules

Treat stored model changes as compatibility-sensitive.

### Current models

- `Folder`
- `Deck`
- `Card`

### Explicit ordering

Never rely on relationship-array order for visible ordering.

Use:

- `Folder.sortOrder` for Home folders
- `Card.position` for cards inside a deck

After move/delete operations, normalize positions where needed and save the `ModelContext`.

### Additive changes

When adding a stored property:

- prefer a default value
- keep old stores readable
- avoid destructive migrations unless explicitly requested
- preserve stable IDs
- preserve relationship semantics
- determine whether the field belongs in backup DTOs
- update smoke tests when the behavior is deterministic and important

### Relationships

Current cascades:

- deleting a `Folder` cascades through its `decks` relationship unless decks are detached first
- deleting a `Deck` cascades through its `cards`

Use `LibraryActions.deleteFolderKeepingDecks` when the requested behavior is “delete folder, preserve decks”.

## 8. Library mutation rules

Reusable library mutations belong in `LibraryActions` when that service already covers the operation.

Current centralized operations include:

- duplicate deck
- duplicate folder
- delete folder while keeping decks
- reset study progress
- move cards
- copy cards
- delete cards
- set starred state

Preserve card ordering when moving/copying/deleting.

Do not copy session progress/history into duplicated decks unless explicitly intended; current duplication copies content/starred state, not the full study-state history.

## 9. Folder drag/reorder — high-risk interaction area

This is currently one of the most regression-sensitive parts of the app.

### Current strategy

`HomeView` currently uses classic SwiftUI drag/drop rather than relying on the newer `reorderable` / `reorderContainer` interaction as the active UI path.

Current moving pieces include:

- `draggedFolderID`
- explicit `onDrag`
- explicit `FolderTile` drag preview
- `FolderReorderDropDelegate`
- `moveFolderDuringCustomDrag`
- `finishFolderCustomDrag`
- transient `folderOrderIDs`
- persisted `Folder.sortOrder`
- geometry-based visual-slot haptics

### Preserve separation of concerns

There are three different behaviors:

1. **Visual drag representation** — what follows the finger.
2. **Live grid order** — where other folders move while dragging.
3. **Persistence** — the final `sortOrder` values.

Do not conflate them.

### Haptic semantics

The desired reorder haptic is tied to a folder actually changing visual slot, not to a batch persistence callback.

Current implementation:

- measures frames in `folder-reorder-grid`
- maps each tile to row/column in a two-column grid
- detects slot changes
- delays initial arming briefly to avoid startup noise
- coalesces very rapid duplicate impacts
- uses `HapticService.play(.reorder)`

Preserve this behavior unless the user specifically asks to change haptics.

### Important runtime history

Recent iOS 27 testing showed disappearing/delayed drag previews, including on an older IPA that had previously behaved correctly. That strongly suggests runtime/platform behavior can change independently of source.

Therefore:

- do not assume every drag regression is caused by the latest commit
- do not repeatedly stack `contentShape`, `compositingGroup`, or opacity hacks without verifying which layer actually owns the preview
- do not reintroduce `.reorderable()` / `.reorderContainer()` casually
- do not hide the source tile unless there is a guaranteed independently rendered floating representation
- validate the actual IPA/device interaction when possible
- CI compilation cannot prove drag-preview correctness

If redesigning drag, preserve immediate visible feedback, live reflow, correct final order, and per-slot haptics.

## 10. App icon — high-risk appearance area

The app has two icon paths that serve different purposes.

### Layered Icon Composer bundle

`Flashcards/AppIcon.icon/` contains:

- `icon.json`
- `Assets/Front_Card.svg`
- `Assets/Middle_Card.svg`
- `Assets/Back_Card.svg`

Current `icon.json` uses Front + Middle as the active layer groups with glass, blur, shadow, translucency, scale, and translation.

Current fill behavior:

- base: automatic dark gradient
- Light specialization: explicit neutral gray linear gradient
- Dark specialization: automatic gradient
- Clear/Tinted are left to platform behavior unless explicitly specialized

### Static fallback/CI path

Also present:

- `Flashcards/icon.png`
- `Flashcards/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

CI requires both static PNGs to be 1024×1024 and byte-identical.

### Rules for icon changes

- Do not assume changing `.icon` updates the static PNG automatically.
- Do not assume the same `automatic-gradient` source value renders identically in Light and Dark.
- Keep appearance-specific changes scoped to the requested appearance.
- Do not modify Clear/Tinted behavior when the request is only about Light/Dark.
- Preserve valid Icon Composer JSON shape and asset names.
- Do not remove currently referenced SVG assets.
- Device rendering is the meaningful validation; JSON similarity alone is insufficient.

## 11. Localization rules

The app supports:

- French
- English
- German
- Spanish
- Automatic system selection

The String Catalog source language is French.

### Preferred mechanisms

Use:

- SwiftUI localized literals / `LocalizedStringKey`
- `Localizable.xcstrings`
- `L10n.text`
- `L10n.format`
- `L10n.cards`, `L10n.decks`, `L10n.questions`

Keep pluralization/formatting centralized.

### `L10n.swift` standalone constraint

`L10n.swift` is compiled directly in Foundation smoke tests.

It must remain usable without linking the app target. In particular, avoid making it depend on:

- `AppSettings`
- `AppLanguage`
- SwiftUI
- SwiftData models
- UIKit

If you intentionally change this constraint, update every smoke-test compile command atomically.

### Inline duplicate translations

`L10n.swift` currently contains inline FR/EN/DE/ES strings for duplicate labels/actions.

For ordinary durable UI copy, prefer the String Catalog. If an inline translation is appropriate, provide all supported languages.

### String Catalog CI contract

Every entry must have an English localization whose `stringUnit.state` is `translated`, because CI validates this with `jq`.

When adding a key, populate EN at minimum for CI and preferably FR/EN/DE/ES for product completeness.

### Literal strings and CI

Some forms intentionally keep literal `Button("Annuler")` source text because the workflow greps it while SwiftUI/String Catalog still localizes it at runtime.

Do not “clean up” audited literals without checking the workflow.

## 12. Duplicate detection rules

Duplicate detection is centralized in `BulkDuplicateDetector`.

Normalization:

- trim whitespace/newlines
- case-insensitive folding
- diacritic-insensitive folding

Semantics:

- exact duplicate = same normalized term + same normalized definition
- possible duplicate = same normalized term + different definition

Candidates are also compared against earlier candidates in the same batch.

Current consumers include:

- new-deck draft cards
- single-card add
- card edit
- bulk import

When editing, exclude the edited card itself from existing-card analysis.

Visual semantics:

- exact → red
- possible → orange

Do not silently discard content without an explicit user choice.

## 13. Bulk import rules

`BulkImportView` + `BulkImportParser` are entirely local.

Preserve:

- clipboard paste support
- configurable term delimiter
- configurable card delimiter
- custom delimiters
- preview
- invalid-record reporting
- duplicate analysis
- skip-exact option
- import-anyway option
- existing-deck import
- new-deck creation flow

Parser behavior should remain deterministic and covered by `CITests/BulkImportParserSmoke.swift` when materially changed.

Do not move parsing to a web service.

## 14. Study rules

Core files:

- `StudySetupView.swift`
- `StudySessionState.swift`
- `StudyView.swift`
- `StudyCardFace.swift`
- `StudyAnimationMetrics.swift`

Current direction modes:

- term → definition
- definition → term
- random

Current sizes:

- 10
- 20
- all

Other preferences:

- shuffle
- starred-only

Outcomes:

- knew
- review

Preserve:

- undo behavior
- previous-progress snapshots
- resumable session encoding
- review-mistakes flow
- card progress accounting
- haptic feedback
- optional completion celebration
- history recording when enabled

`StudySessionState` is Foundation-testable. Keep UI-only dependencies out of it unless intentionally changing the test architecture.

## 15. Test-mode rules

Core files:

- `TestSetupView.swift`
- `TestSessionState.swift`
- `TestRunView.swift`
- `TestAnimationMetrics.swift`

Question types:

- multiple choice
- true / false
- written

Preserve:

- direction semantics
- shuffle behavior
- unique distractor normalization
- written-answer normalization
- manual written-answer override
- retry-errors behavior
- keyboard submit path for written answers
- study-history accounting

`TestSessionState` is included in Foundation smoke tests; keep it lightweight.

## 16. Study history rules

Study history lives as encoded local data in `Deck.studyHistoryData`.

Current history is bounded to five entries.

Each entry stores:

- completion date
- Flashcards/Test mode
- item count
- correct count
- incorrect count

The UI can:

- disable history globally
- delete one entry
- clear a deck's history

Do not turn history into a server-side analytics feature.

## 17. Backup compatibility rules

JSON backup/restore is not optional polish; treat it as a persistence contract.

Current schema:

- `BackupEnvelopeV1`
- `schemaVersion = 1`
- scopes: `deck`, `database`

### When adding meaningful user-owned state

Ask whether the field must survive export/import. If yes:

- add it to the appropriate DTO
- export it
- import it
- use `decodeIfPresent` + safe defaults for backward-compatible additive fields
- preserve stable IDs
- preserve relationships
- update `BackupCodecSmoke.swift`

Do not bump schema version for every additive optional/defaulted field.

### Import semantics

Current restore is a merge/upsert by UUID.

- incoming matching objects update local objects
- missing incoming objects are added
- local objects absent from the file are not deleted
- import failure rolls back the model context

Do not silently change restore into “replace database” behavior.

### Known current caveat

`Deck.deckDescription` is not included in `BackupDeckDTO` today.

## 18. Settings and preferences rules

Current `SettingsView` exposes:

- haptics
- celebrations
- study history
- Resume section
- Recent section
- Pinned section
- search scope behavior
- language
- backup/restore

`AppPreferences` stores values in `UserDefaults`; `AppSettings` mirrors them as observable state.

Do not expose an accent/theme selector unless explicitly requested. The current app accent is fixed mint.

## 19. Haptic rules

Use `HapticService`.

Current events:

- selection
- reorder
- flip
- correct
- review
- wrong
- completion

Respect `AppPreferences.hapticsEnabled`.

Do not scatter new `UIImpactFeedbackGenerator` usage around views if the event belongs in the centralized service.

For drag/reorder, preserve the existing slot-change semantics unless specifically asked otherwise.

## 20. CI is a repository contract

`.github/workflows/build-ipa.yml` is intentionally strict and contains brittle grep-based assertions.

Before changing an audited file, inspect the workflow.

### Architectural forbidden-pattern audit

Current CI fails if source under `Flashcards` contains patterns matching:

```text
URLSession
import Network
import CloudKit
NSPersistentCloudKitContainer
Analytics
Tracking
```

Because this is grep-based, even a symbol/comment containing the literal substring `Tracking` can fail.

CI also rejects CloudKit configurations using automatic/private database selection and requires `cloudKitDatabase: .none`.

### Additional forbidden source terms

Current workflow rejects these patterns in `Flashcards` / `CITests`:

```text
StudyRound
currentRound
nextRound
roundNumber
feedbackMilliseconds
card(s)
carte(s)
Tabulation
accentHex
```

Do not introduce them casually, including in comments/test fixtures, unless updating the audit intentionally.

## 21. Exact CI assertions agents should know

The current workflow expects several exact source contracts. These are implementation checks, not eternal product laws, but they must be handled deliberately.

### Theme / assets

CI expects the exact line:

```swift
static var accent: Color { AppPreferences.accentColor.color }
```

It also expects:

- no `AccentColor.colorset`
- `FolderAppearance.swift` does not contain `FF3B30`
- `FolderAppearance.swift` contains `"FF2D55"`

If the design intentionally changes, update the audit atomically rather than adding dead compatibility text.

### Home/search

CI currently expects:

- leading toolbar item on Home
- trailing toolbar group on Home
- Home magnifying-glass action
- global `DeckSearchView(... showsFolderContext: true)`
- folder `DeckSearchView(... showsFolderContext: false)`
- `.searchable` only in `DeckRow.swift`
- Recent uses `.prefix(2)`
- source order `Reprendre` < `Récents` < `Épinglés` < `Dossiers`
- `private var pinnedDecks: [Deck]`
- Home uses `DeckTile(deck: deck)`

### Data/state APIs

CI expects:

- `Deck.activeStudySessionData`
- `Deck.lastOpenedAt`
- `Deck.studyHistoryData`
- `Deck.isPinned`
- `Card.isStarred`
- `StudySessionState.undoLastAnswer()`
- `StudyCardProgressSnapshot`
- `BulkDuplicateDetector`

### Study/Test UI

CI expects:

- `Button("study.review_mistakes"` in `StudyView`
- `allowsHitTesting(!isCommitting)` in `StudyView`
- written answer submit through `onSubmit { submitWrittenAnswer() }`
- `private var accent: Color { Theme.deckAccent(for: deck) }` in Study/Test setup/run files
- `Button("Continuer", role: .destructive)` in `StudySetupView`

### Bulk import

CI expects:

- default `termOption = TermDefinitionDelimiterOption.colon`
- clipboard access via `UIPasteboard.general.string`
- literal buttons `Button("Ignorer les doublons exacts")` and `Button("Importer quand même")`
- `Button("Annuler")`
- `CircularSaveButton(`

### Library layout/components

CI expects:

- Folder detail uses `LazyVStack(spacing: 10)`
- `DeckRow.swift` references `deck.folder?.name`
- no `DeckRow(deck:` use inside `DeckRow.swift`
- `DeckRow` contains `private func cardPreview`
- `Theme.deckAccent(for:)`
- deck detail uses the contextual accent several times
- `CircularSaveButton`, `DeckProgressBar`, and `CardEditorSurface` exist in `Theme.swift`
- `DeckFormView` and `CardFormView` use `CardEditorSurface`
- `DeckDetailView` and `StudySetupView` use `DeckProgressBar`

### Form toolbar literals

For each of these:

- `FolderFormView.swift`
- `DeckFormView.swift`
- `CardFormView.swift`

CI expects:

- cancellation toolbar placement
- literal `Button("Annuler")`
- confirmation toolbar placement
- `CircularSaveButton(`

`EditCardsView` transfer sheet has similar audited cancel/save requirements.

### Haptics/project structure

CI expects:

- `import CoreHaptics` in `HapticService.swift`
- `cloudKitDatabase: .none`
- no remote Swift package references
- no package product dependencies
- no system capabilities in the project
- one `PBXNativeTarget`
- iOS 26.0 deployment target in both configurations
- Swift 6.0 in both configurations
- bundle ID `com.raton.flashcards`
- no `.entitlements`
- no `Package.swift` / `Package.resolved`

### Localization catalog

CI expects:

- `sourceLanguage == "fr"`
- catalog version `1.0`
- every string entry has English state `translated`

## 22. Do not game stale CI

If a legitimate product/source change makes an audit obsolete:

**Do:**

- update source correctly
- update the corresponding workflow assertion in the same logical change
- explain the contract change

**Do not:**

- add dead variables only to satisfy grep
- leave fake literal strings in comments
- preserve unused obsolete code solely for CI
- weaken privacy/offline audits when the architecture has not changed

The workflow should describe the intended repository, not force the product to remain frozen.

## 23. Foundation smoke-test constraints

The workflow directly compiles small source sets with `xcrun swiftc -swift-version 6`.

Current harnesses:

- `BulkImportParserSmoke.swift`
- `StudySessionSmoke.swift`
- `TestSessionSmoke.swift`
- `BackupCodecSmoke.swift`

Keep tested services Foundation-friendly.

When changing these domains:

- run/update the matching smoke harness if possible
- do not introduce UI-only imports into deterministic state code without need
- update the workflow compile list if a new required dependency is intentional

## 24. App build / validation rules

The project may be edited from Linux/non-macOS environments, so GitHub Actions is the primary compilation/build validation path in many workflows.

Before declaring a change complete:

- inspect final diff
- verify no unrelated files changed
- fetch the resulting commit
- check CI status when available
- if workflow status is empty/pending, say so

Never claim:

- “Xcode build passed” when no build was run
- “CI passed” when no success status is available
- “device behavior fixed” when only compile/static checks were performed

For visual/runtime interactions such as drag previews or Icon Composer appearance rendering, explicitly state when actual-device validation is still needed.

## 25. Release/version rules

The workflow owns release versioning.

### Normal push to `main`

Normal pushes:

- use the current project version
- run audits/tests/build
- package unsigned IPA
- publish one normal release per push only in the private `raaaton/Kavi-builds` repository
- tag it `vMAJOR.MINOR.PATCH-build.RUN_NUMBER`
- name its sole asset `Kavi-MAJOR.MINOR.PATCH-build.RUN_NUMBER.ipa`
- keep earlier private releases as downloadable build history
- authenticate cross-repository publication through the `KAVI_BUILDS_TOKEN` Actions secret
- do not upload the IPA as a public Actions artifact or public release asset

Do not manually bump release metadata for ordinary feature/fix work.

### Manual release (`workflow_dispatch`)

The workflow reads repository variables:

- `RELEASE_MAJOR`
- `RELEASE_MINOR`

Rules:

- `RELEASE_MAJOR` defaults to `1` if absent
- both values must be integers
- patch comes from matching `vMAJOR.MINOR.*` tags
- first matching series release is `.0`
- marketing version = `MAJOR.MINOR.PATCH`
- build version = `MINOR.PATCH`

Manual release also updates the project version and commits release metadata with `[skip ci]`. It publishes the IPA only as a normal versioned release in the private builds repository and creates the official public GitHub release/tag without a binary asset.

### Agents must not manually bump

Unless the task is specifically about release/version workflow behavior, do not manually edit:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`
- release tags

## 26. Public distribution rules

- The public repository must not expose downloadable IPA files through releases or Actions artifacts.
- The public README must not contain a development IPA download link.
- Prebuilt IPA distribution belongs only in normal releases of the private `raaaton/Kavi-builds` repository.
- Every push to `main` produces a distinct private release and retains earlier releases as build history.
- Never hard-code a cross-repository token; use the `KAVI_BUILDS_TOKEN` Actions secret.

Public release tags and metadata may remain for version history, but they must not carry IPA assets.

## 27. Git behavior

Use Conventional Commit-style messages consistent with repository history:

- `feat: ...`
- `fix: ...`
- `docs: ...`
- `refactor: ...`
- `chore: ...`
- `revert: ...`

Prefer one logical final commit for one requested change.

### Before writing

- verify current `main` head
- avoid overwriting concurrent user changes
- when modifying multiple files that form one change, prefer an atomic tree/commit if the tool supports it

### History safety

Do not:

- force-push `main`
- rewrite published history
- rename old commits
- reset user commits

unless the user explicitly requests history rewriting.

Temporary tool-created commits may be cleaned up only when safe, authorized, and confined to the current operation.

## 28. Connected GitHub editing rules

When operating through GitHub tools:

- fetch the current file SHA before `update_file`
- if `update_file` returns a SHA conflict, refetch rather than forcing stale content
- after a multi-file change, fetch the final commit/diff
- do not claim local filesystem files were modified when only GitHub was changed
- cite/describe the actual pushed commit in the completion message

## 29. Accessibility / semantics

Preserve existing accessibility labels/values when modifying visual wrappers.

When adding interactive controls:

- provide meaningful labels for icon-only buttons
- preserve disabled-state semantics
- keep touch targets reasonable
- avoid making decorative layers hit-testable

Do not trade accessibility for visual mimicry.

## 30. Direct-manipulation behavior

For drag, swipe, flip, reorder, and animated transitions:

- the object being manipulated should remain visually attributable to the user's gesture
- surrounding layout should react predictably
- model state should not visibly “teleport” after a long delay
- haptics should correspond to meaningful state/slot changes
- persistence timing should not create visible stale-state flashes

If a system API becomes unreliable on the current iOS runtime, a small custom SwiftUI interaction is acceptable, but keep it understandable and test actual runtime behavior.

## 31. Performance guidance

The app is small; avoid premature optimization.

Still:

- do not do expensive repeated work in `body` when it can be computed cleanly once
- keep drag/update loops lightweight
- avoid unnecessary SwiftData saves on every tiny visual frame unless persistence requires it
- avoid large synchronous file work on the main interaction path
- keep history bounded as designed

Prefer correctness/readability over micro-optimization.

## 32. Error handling

User-facing file/import failures should surface useful localized errors.

For persistence:

- current simple mutations often use `try? modelContext.save()`
- backup import uses explicit `do/catch`, rollback, and user-facing error reporting

Do not silently swallow errors in flows where failure would lose or misrepresent user data.

## 33. Privacy rules

Never add:

- telemetry
- analytics SDKs
- advertising IDs
- remote logging
- background uploads
- contact/account collection
- remote card processing

without explicit product direction.

The absence of network access is a deliberate product property and CI-enforced architecture invariant.

## 34. Comments and naming

Prefer names that explain intent.

Good comments document:

- why iOS runtime behavior requires a workaround
- why a legacy field remains
- why a timing threshold exists
- why a CI/source literal must remain until an assertion changes
- migration/backup compatibility behavior

Bad comments:

- restate the next line
- preserve fake forbidden/required strings just for grep
- speculate about platform behavior without evidence

## 35. When to update `PROJECT.md` / `AGENTS.md`

Update `PROJECT.md` when changing:

- architecture
- persistent models
- major feature flows
- design-system invariants
- backup semantics
- release strategy
- folder reorder architecture
- icon pipeline
- supported languages
- repository layout

Update `AGENTS.md` when changing:

- workflow/audit contracts
- agent-safe editing rules
- fragile runtime workarounds
- release ownership
- validation requirements
- known compatibility traps

Do not leave these files knowingly stale after a major architectural change.

## 36. Definition of done

A coding task is complete when all relevant conditions are true:

- requested behavior is implemented
- final implementation matches current v2/native design language
- no unrelated behavior was changed
- persistence/order remains correct
- backup compatibility is handled when relevant
- localization is handled when relevant
- deterministic tests are updated when relevant
- CI assertions match the intended source
- final diff is reviewed
- commit message accurately describes the change
- result is pushed to the intended branch
- CI/build validation status is reported accurately
- runtime-only uncertainty is disclosed instead of guessed

## 37. Final reporting style

When reporting a completed repository change:

- state what changed
- name the commit SHA/message
- mention CI/build status only if actually checked
- mention any meaningful validation limitation

Do not write a long victory summary for a tiny change, but do not hide uncertainty for interaction-heavy changes.
