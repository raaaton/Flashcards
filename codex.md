# Flashcards — project context

## Project

- Native iPhone app, iOS 27+, Swift 6, SwiftUI and SwiftData.
- Bundle identifier: `com.raton.flashcards`; one dark-only application target.
- Local `ModelContainer` with `cloudKitDatabase: .none`.
- French, English, or automatic device language.
- No runtime dependency, network, account, backend, cloud, analytics, ads, purchases, AI, entitlement, or extension.
- Unsigned IPA distribution through GitHub Releases for SideStore/AltStore.

## Architecture

### Persistent models

- `Folder`: UUID, name, creation date, SF Symbol, color hex, cascade relationship to decks.
- `Deck`: UUID, metadata/timestamps, folder, cascade cards, Recent date, pin, completed-session count, active Flashcards snapshot, last study activity, and encoded history.
- `Card`: UUID, term, definition, ordered position, mastery, studied/correct counters, favorite flag, and deck.

Folder deletion either detaches its decks or cascades through decks/cards after an explicit choice. Moving a card preserves its UUID, progress, statistics, and favorite state. Copying creates a new UUID, preserves text/favorite state, and resets progress/statistics. Backup decoding keeps defaults for fields absent from older JSON.

### Logic and services

- `LibraryActions`: deep duplication, folder-preserving deletion, progress reset, multi-delete, star/unstar, move, copy, and position normalization.
- `BulkImportParser` / `BulkDuplicateDetector`: literal delimiter parsing, invalid records, exact and possible duplicate analysis.
- `StudySessionState` / `StudySessionPersistence`: fixed one-pass session, Codable judgments, multiple Undo, and exact Resume.
- `TestSessionState` / `TestQuestionFactory`: QCM, true/false, written answers, normalization, scoring, override, and retry-errors.
- `BackupCodec`, `BackupMerger`, `BackupService`: versioned JSON, validation, UUID merge, SwiftData import, rollback on save failure.
- `AppSettings` / `AppPreferences`: immediate `UserDefaults` preferences.
- `HapticService`: setting-aware feedback and Core Haptics completion sequence.

## Home, navigation, and search

Home’s conditional order is always:

```text
Quick Resume   if a Flashcards session is active
Recent         if available (two latest opened decks)
Pinned         if available
Folders        plus optional Unfiled
```

Quick Resume selects the active session with the latest study activity and opens its exact persisted snapshot. Deck context menus expose Pin/Unpin. Recent, Pinned, Folder, and Search reuse the same near-square `DeckTile`; folders reuse `FolderTile`.

There is no persistent search bar:

```text
Home search icon → global folders, deck names/descriptions, and card terms/definitions
Folder search icon → decks in that folder only
```

Global card results are compact previews with Term, Definition, and `Folder › Deck`; tapping opens the owning deck. Global folder results keep the modern folder tile.

Deck detail contains progress, Flashcards/Test tiles, up to five completed history entries, card editing, JSON export, edit, and destructive delete. Edit Cards supports add/edit/delete, visible favorites, drag reorder, native multi-selection, batch Delete/Move/Copy/Star/Unstar, and Bulk Add.

Standard creation/edit sheets use leading **Cancel** and trailing **Save**. The deliberate Bulk Import exception is leading **Close** and a white icon-only trailing checkmark. Settings and Backup apply changes immediately and use dismissal controls.

## Contextual appearance

`Theme.deckAccent(for:)` is the only source of contextual deck color:

```text
Deck in Folder → Folder color
Deck without Folder → Apple system blue
```

It applies to Deck progress/actions and the complete Flashcards/Test flows: Start/Resume, direction, toggles, segmented session size, neutral progress and result accents. Semantic colors remain independent:

```text
correct/success → green
incorrect/review/destructive → red
neutral icon-only toolbar action → white
```

The folder picker retains existing useful symbols and adds a bounded school-oriented SF Symbols set for computing, mathematics, science, biology, economics, geography, literature, languages, art, and music. The classic `FF3B30` red is no longer selectable; the softer `FF2D55` remains. Existing stored folder colors are never migrated.

## Flashcards behavior

- No automatic rounds: each selected card appears at most once per session.
- A normal Start uses non-mastered cards; optional Starred only and fixed Session Size 10/20/All are applied once at Start.
- Direction is term→definition, definition→term, or random per card; Shuffle is fixed for the session.
- “I knew it” increments studied/correct and masters the card. “Review” increments studied and leaves it unmastered.
- Every judgment stores its pre-answer card snapshot. Undo can roll back several judgments exactly: index/counters, `mastered`, `timesStudied`, and `timesCorrect`.
- An incomplete quit persists the exact subset, order, index, options, and Undo history. Resume never reselects 10/20 cards.
- Completed sessions are stored once in the deck history (maximum five persisted/displayed entries).
- Session Complete offers Review mistakes only when needed. It explicitly creates a new numbered session from the previous session’s reviewed cards; it never auto-starts.
- Starting after full mastery asks before resetting the series. Reset and deletion remain destructive/confirmed.
- Flip/swipe animations, VoiceOver actions, optional celebration, and haptics remain native and setting-aware.

## Test behavior

- Configuration requires at least one of QCM, True/False, or written answer.
- Direction, Shuffle, Starred only, and Session Size 10/20/All create one fixed question pool.
- QCM uses distinct distractors and gracefully reduces choices for small decks. True/False uses real/mismatched pairs; one-card decks produce a true pair.
- Written comparison normalizes case, accents, width, and repeated whitespace; a false answer can be manually overridden without double-counting.
- Submit/Next are explicit. Results show score and review, with retry-errors preserving the original erroneous questions.
- Tests update studied/correct counters, never mastery, and completed results are added once to the five-entry deck history.

## Bulk Import and backup

- Bulk Add/Import uses one shared literal parser. Defaults are colon between term/definition and newline between cards; the first term separator wins.
- Empty records are ignored; surrounding whitespace is trimmed; invalid rows are visible and do not block valid rows.
- Smart Paste reads `UIPasteboard` only after a user taps Paste. Invalid clipboard text never overwrites existing editor content.
- Exact duplicates use lightly normalized Term + Definition; possible duplicates use the same Term with another Definition. The preview identifies affected rows.
- Exact duplicates always require an explicit Skip duplicates / Import anyway choice. Possible duplicates are never silently removed.
- New Deck Bulk Add compares against drafted cards and earlier pasted rows. SwiftData is not mutated before confirmation.
- Import creates a deck or appends ordered positions to an existing deck.
- `BackupEnvelopeV1` (`schemaVersion = 1`) exports folders, decks, cards, relationships, positions, statistics, favorites, pins, history, Recent, and Resume state.
- Import is a non-destructive UUID merge. Unknown/empty data is rejected before mutation; absent local objects are kept; save failure rolls the context back.

## Settings

Only haptics, celebrations, language (automatic/French/English), and the Backup entry point exist. Do not restore removed settings.

## CI, distribution, and versioning

`.github/workflows/build-ipa.yml` runs on `xcode-27` for `main`, `v*` tags, and manual dispatch. It prints toolchain versions, audits offline/single-target/version/UI invariants, runs Foundation smoke harnesses, builds unsigned Release for `iphoneos`, builds/installs/launches on an iOS 27 simulator, packages `Flashcards.ipa`, and publishes Releases.

```text
app X.Y → green main CI → tag vX.Y → green tag CI
→ GitHub Release vX.Y → Flashcards.ipa
```

Main pushes produce technical `build-N` releases. Official tags produce the matching official release.

## DO NOT BREAK

- Preserve SwiftData field compatibility, UUIDs, relationships, order, mastery, statistics, favorites, pin, history, Recent, and active snapshots.
- Never add runtime networking, accounts, backend, iCloud/CloudKit, analytics, ads, payments, AI, third-party packages, entitlements, extensions, or another target.
- Keep iOS 27+, SwiftUI, SwiftData local-only, dark-only, one target, and no runtime network access.
- Never reintroduce automatic Flashcards rounds.
- Incomplete quit must Resume the exact subset/order/options/Undo history; Undo must roll back the last judgment exactly.
- Review mistakes must always be explicit/manual and start a separate numbered session.
- Never recalculate a fixed Session Size subset during Resume.
- Keep Search behind white icon-only toolbar actions; do not add a persistent Home/Folder search bar.
- Reuse the modern Deck tile in Recent, Pinned, Folder, and Search.
- Keep folder accent throughout its deck’s study flows, system blue without a folder, green/red semantics, white neutral icons, and red destructive actions/swipes.
- Keep create/edit sheets Cancel/Save and Bulk Import Close/checkmark.
- Keep parser duplicate choices and Backup merge semantics explicit and non-destructive.
