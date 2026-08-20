# Flashcards — project context

## Project

- App: **Flashcards**
- Platform: iOS 27+, iPhone only
- Bundle identifier: `com.raton.flashcards`
- UI: SwiftUI, system navigation and Liquid Glass controls
- Persistence: SwiftData, local `ModelContainer` with `cloudKitDatabase: .none`
- Language: French, English, or automatic device language
- Theme: dark-only
- Runtime dependencies: none
- Network, backend, cloud, analytics, account, ads, purchases: none

The repository contains one application target. It is intended for unsigned IPA distribution and local installation with SideStore or AltStore.

## Architecture

### Persistent models

- `Folder`: UUID, name, creation date, SF Symbol name, color hex, and a cascade relationship to its decks.
- `Deck`: UUID, name, optional description, timestamps, optional `lastOpenedAt`, completed study-session count, optional encoded active-session data, optional folder, and a cascade relationship to cards.
- `Card`: UUID, term, definition, ordered position, mastered flag, study/correct counters, and optional deck.

Deleting a deck cascades to its cards. Folder deletion has two explicit product paths: detach and preserve its decks, or delete the folder and cascade through its decks/cards. Existing UUIDs and relationships must remain compatible with stored SwiftData data.

`lastOpenedAt` drives the two most recent decks on Home. `activeStudySessionData` stores a Codable `ActiveStudySessionSnapshot` so an unfinished Flashcards session can resume with its original item order and index.

### Logic and services

- `LibraryActions`: duplication, folder-preserving deletion, and study-progression reset.
- `BulkImportParser`: literal delimiter parsing and valid/invalid preview records.
- `StudySessionState` / `StudySessionPersistence`: one-pass Flashcards sessions and Resume snapshots.
- `TestSessionState` / `TestQuestionFactory`: question generation, answer normalization, scoring, override, and retry-errors state.
- `BackupCodec`, `BackupMerger`, and `BackupService`: versioned JSON encoding, validation, merge, SwiftData import, and rollback on save failure.
- `AppSettings` and `AppPreferences`: observable UI state backed by `UserDefaults`.
- `HapticService`: setting-aware feedback, including the strong completion Core Haptics sequence and a multi-impact fallback.

## Navigation and UI

- Home: Settings at top-left; temporary Search and Add at top-right. Recent decks appear first when available, followed by the folder grid and optional “Unfiled” tile.
- Search: icon-only entry points open a temporary native search interface. Home searches every deck and card; a Folder search receives only that folder’s decks. There is no persistent Search Bar in Home or Folder layouts.
- Folder: responsive near-square deck grid. Tiles open a Deck; management remains available through context menus and the folder action menu.
- Deck: progress summary, Flashcards and Test entry tiles, card editor, JSON export, edit, and destructive delete.
- Edit Cards: add/edit/delete, drag reorder, and Bulk Add.
- Settings: haptics toggle, celebrations toggle, language picker (automatic/French/English), and Backup.
- Backup: deck export or full database export/import through system file/share UI.

Creation and edit sheets use **Cancel** on the leading side and **Save** on the trailing side. Bulk Import is the deliberate exception: **Close** leading and a white icon-only checkmark trailing.

## Folder colors and action colors

`Theme.deckAccent(for:)` is the single source for a Deck’s contextual accent:

```text
Folder color
→ Deck progress fill
→ Flashcards/Test tile backgrounds
→ Edit cards icon and text

No folder
→ Apple system blue
```

This does not replace the global blue accent and never recolors global navigation, Settings, unrelated actions, or destructive actions.

Critical color rules:

```text
neutral icon-only action → white
normal icon + text action → contextual accent (global blue unless locally scoped)
destructive action → red
destructive swipe → red full background + white trash icon
```

## Flashcards behavior

- There are no automatic rounds.
- Start creates one session from all currently non-mastered cards; each eligible card appears once in that session.
- “I knew it” marks the card mastered and increments studied/correct statistics.
- “Review” increments studied statistics and leaves the card non-mastered for a future session.
- Leaving an incomplete session preserves a Resume snapshot. Resume keeps the same direction, shuffle choice, order, and current index.
- Shuffle applies only when creating a new session.
- The deck stores a completed-session counter and persistent mastery progress.
- Starting when every card is mastered shows a destructive red Continue action because it resets progress before creating a new series.
- Flip and swipe use native SwiftUI gestures/animations. Completion confetti and strong haptics occur only at a real 100% completion and respect Settings.

## Test behavior

- Configuration supports multiple choice, true/false, and written answers; at least one type is required.
- Direction is term→definition, definition→term, or random. Shuffle and a whole-deck/subset question count are configurable.
- QCM uses one correct answer plus distinct deck distractors, reduced for small decks.
- True/False uses a real or mismatched pair; a one-card deck produces a true pair.
- Written answers normalize case, accents, width, and repeated whitespace. A false written answer can be manually overridden.
- Feedback is shown after Submit; Next is manual. Keyboard Return submits a written answer.
- Results include score, per-question review, retry-errors, and completion celebration behavior.
- Test updates study/correct counters but does not change `mastered`.

## Bulk Import and backup

- Bulk Add/Import parses pasted text with a literal term/definition delimiter and a literal card delimiter.
- The current default term delimiter is colon; the current default card delimiter is newline. Presets and non-empty custom delimiters are supported.
- Parsing splits on the first term delimiter, trims surrounding whitespace, ignores wholly empty records, previews valid cards, and reports invalid records without blocking valid imports.
- Import can create a named deck or append to an existing deck; appended positions continue after existing cards.
- JSON uses `BackupEnvelopeV1` (`schemaVersion = 1`) with ISO-8601 dates, scope, folders, decks, cards, relationships, progress statistics, recent timestamps, and Resume data.
- Backup import is a UUID-based non-destructive merge: incoming objects update matching UUIDs, new UUIDs are inserted, and local objects absent from the file remain. Unsupported/empty backups are rejected before mutation; SwiftData rolls back if saving fails.

## Settings

Only these settings currently exist:

- Haptics enabled
- Celebrations enabled
- Language: automatic, French, or English
- Backup entry point (action, not a stored preference)

Do not document or restore removed settings.

## CI, distribution, and versioning

`.github/workflows/build-ipa.yml` runs on GitHub Actions `xcode-27` for pushes to `main`, `v*` tags, and manual dispatch. It:

1. reports Xcode, Swift, iOS SDK, and `gh` versions;
2. validates the icon and offline/single-target invariants;
3. compiles Foundation smoke-test harnesses;
4. builds an unsigned Release for `iphoneos`;
5. builds, installs, and launches the app on an iOS 27 simulator;
6. packages `Payload/Flashcards.app` as `Flashcards.ipa`;
7. publishes technical `build-N` releases for `main`, or an official `vX.Y` release for a matching version tag.

The official version flow is:

```text
app version X.Y → green main CI → tag vX.Y → green tag CI
→ GitHub Release vX.Y → Flashcards.ipa → SideStore/AltStore
```

Use small logical commits. Do not wait for CI after every tiny commit; push a coherent group, fix any red CI before stacking unrelated work, and require a final green CI before tagging a release.

## DO NOT BREAK

- Do not rewrite the app or rename/retype persistent SwiftData fields casually.
- Preserve existing local data, UUIDs, relationships, card order, progress, statistics, Recent data, and Resume snapshots.
- Do not add runtime networking, accounts, backend, CloudKit/iCloud, analytics, ads, subscriptions, or AI.
- Do not add third-party runtime dependencies, SPM packages, entitlements, extensions, or additional targets.
- Keep iOS 27+, SwiftUI, SwiftData local-only, one target, dark-only, and no runtime network access.
- Do not reintroduce automatic Flashcards rounds.
- Do not reintroduce a persistent Search Bar; Search starts from white icon-only toolbar buttons.
- Keep neutral icon-only actions white, normal labeled actions accented, and destructive actions red.
- Keep every destructive swipe’s entire background red with a white trash icon.
- Keep Folder color contextual to its decks only; no-folder decks fall back to system blue.
- Keep Bulk Import parsing behavior and Backup merge semantics stable unless explicitly requested.
- Keep destructive data resets/deletions explicit and confirmed.
