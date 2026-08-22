![header](https://github.com/user-attachments/assets/03162523-f774-46c7-8748-eeb635d48c92)

<p align="center">
  <img alt="release" src="https://img.shields.io/github/v/release/raaaton/Flashcards" />
  <img alt="stars" src="https://img.shields.io/github/stars/raaaton/Flashcards" />
  <img alt="forks" src="https://img.shields.io/github/forks/raaaton/Flashcards" />
  <img alt="issues" src="https://img.shields.io/github/issues/raaaton/Flashcards" />
</p>

# Flashcards

**Flashcards** is a native, local-first iOS study app built for fast card creation, focused revision, and full ownership of your data.

It is written entirely with **SwiftUI**, **SwiftData**, and Apple system APIs. There is no account, backend, analytics SDK, advertising layer, or runtime network dependency.

Version 2 introduces a redesigned visual system, a new mint identity, a rebuilt Home experience, compact deck rows, improved duplicate detection, configurable Home sections, expanded localization, and a more consistent Apple-native interaction model throughout the app.

---

## Development Build

<!-- DEV_IPA_START -->
[⬇️ **Download latest development IPA**](https://github.com/raaaton/Flashcards/releases/download/dev/Flashcards-v2.0.0.ipa)
<!-- DEV_IPA_END -->

> Built automatically from the latest commit on `main`. Development builds may contain unfinished or unstable changes.

Stable releases are available from the repository's [Releases](https://github.com/raaaton/Flashcards/releases) page.

---

## Version 2

The v2 generation is a major visual and interaction refresh rather than a simple coat of paint.

- New app-wide **mint identity** based around `#46D7A7`
- New layered app icon using Apple's `.icon` format
- Rebuilt Home hierarchy with **Resume**, **Recent**, **Pinned**, and **Folders**
- Optional Home sections configurable from Settings
- Uniform folder design with SF Symbols and mint icon surfaces
- Compact, full-width deck rows instead of the previous card grid treatment
- Matching deck presentation between Home, search, and folder pages
- Expanded deck context menus with pin, edit, duplicate, and delete actions
- Improved first-deck onboarding
- More consistent native sheets, menus, alerts, haptics, and Liquid Glass controls
- Duplicate detection extended beyond bulk import to normal card creation and editing
- French, English, German, and Spanish localization

# SCREEN NECESSAIRE : Home v2 showing Resume, Recent, Pinned and the redesigned Folder tiles

# SCREEN NECESSAIRE : A folder page showing the new compact full-width Deck rows

---

## Features

### Organize your library

Flashcards uses a simple hierarchy:

```text
Folder
└── Deck
    └── Cards
```

Folders keep subjects or themes separated while decks remain the unit you actually study.

- Create folders with custom SF Symbols
- Reorder folders directly from Home
- Create multiple decks inside each folder
- Keep decks without a folder when you do not need extra organization
- Pin important decks
- Quickly reopen recently used decks
- Resume unfinished study sessions directly from Home
- Edit, duplicate, pin/unpin, or delete decks from contextual menus
- Edit, duplicate, or delete folders from contextual menus
- Move or copy cards between decks
- Search across folders, deck names, terms, and definitions
- Optionally restrict search to the current folder

The v2 interface intentionally removes per-folder accent colors from the visible design. Folders now share the same neutral card treatment and mint icon language so the library reads as one coherent system.

---

### Create cards quickly

Cards can be created one at a time or in large batches without leaving the app.

- Add and edit cards individually
- Create a new deck with several initial cards in one flow
- Add more card editors while creating a deck
- Delete draft cards before saving
- Select multiple existing cards for bulk actions
- Star or unstar cards
- Delete selected cards
- Move selected cards to another deck
- Copy selected cards to another deck
- Reorder cards inside a deck

#### Duplicate detection

Duplicate detection is available during normal creation as well as bulk import.

Flashcards distinguishes between:

- **Exact duplicate** — same normalized term and definition
- **Possible duplicate** — same normalized term with a different definition

Exact duplicates use semantic red feedback, while possible duplicates use orange warnings. Before saving, the app can warn you and let you continue deliberately instead of silently creating duplicate content.

This applies when:

- Creating cards inside a new deck
- Adding a single card to an existing deck
- Editing an existing card
- Using Bulk Add / Bulk Import

When editing a card, the card itself is excluded from duplicate comparison.

# SCREEN NECESSAIRE : New Deck or Add Card screen with an Exact duplicate / Possible duplicate warning visible

---

### Bulk Add & Import

Large card sets can be pasted as plain text and parsed directly on-device.

- Paste directly from the clipboard
- Configure the delimiter between term and definition
- Configure the delimiter between cards
- Use custom delimiters
- Preview parsed cards before importing
- See invalid records before saving
- Detect exact and possible duplicates in the preview
- Skip exact duplicates or import anyway
- Import into an existing deck
- Create a new deck directly from the importer

A simple input can look like:

```text
France:Paris
Germany:Berlin
Spain:Madrid
```

No external parser or online service is used.

---

## Study with Flashcards

Flashcards mode is built around one card at a time, with the surrounding UI kept deliberately quiet.

- Study **term → definition**
- Study **definition → term**
- Randomize direction when desired
- Shuffle cards
- Study starred cards only
- Choose the session size
- Flip cards with an animated 3D transition
- Swipe right for **Correct**
- Swipe left for **Review**
- Undo the previous judgment
- Resume unfinished sessions later
- Review mistakes in a dedicated follow-up session
- Track mastered cards and deck progress
- Save completed sessions to local study history
- Native haptic feedback
- Optional completion celebrations

Study preferences are remembered locally so repeated sessions do not need to be configured from scratch.

# SCREEN NECESSAIRE : Flashcards study screen with a card flipped to its answer side

---

## Test yourself

The same deck can also generate mixed tests instead of swipe-based flashcards.

Supported question formats:

- **Multiple Choice**
- **True / False**
- **Written Answer**

Tests reuse the same library and can respect the same study preferences such as direction, shuffle, starred-only filtering, and session size.

Written answers can be submitted directly from the keyboard, while every test run stays completely on-device.

# SCREEN NECESSAIRE : Test screen showing either Multiple Choice or Written Answer mode

---

## Study history & progress

Completed study sessions can be stored locally per deck.

History entries include information such as:

- Study mode
- Number of studied items
- Correct answers
- Incorrect answers
- Success rate
- Completion date

Deck pages also show mastered-card progress, giving a quick overview without introducing accounts, streak systems, or server-side statistics.

Study history can be disabled from Settings, and an individual deck's history can be cleared at any time.

---

## Search

Search is integrated into the native navigation flow rather than permanently occupying space on Home.

Depending on scope, it can match:

- Folder names
- Deck names
- Card terms
- Card definitions

When searching globally, card results show their folder and deck context. When opened from a folder, search can remain limited to that folder or expand globally depending on the Settings preference.

---

## Home customization

The Home screen can be adjusted without changing the core library structure.

The following sections can independently be enabled or disabled:

- **Resume** — unfinished study sessions
- **Recent** — recently opened decks
- **Pinned** — explicitly pinned decks

Folders remain the primary library entry point below those optional sections.

---

## Settings

Settings currently include controls for:

- Haptic feedback
- Celebration animations
- Study history
- Resume section on Home
- Recent section on Home
- Pinned section on Home
- Folder-scoped search behavior
- App language
- Backup and restore

The visual identity itself is intentionally fixed rather than user-configurable: mint is the app's brand accent, while red and orange remain reserved for semantic warnings and destructive states.

---

## Backup & restore

Your data is not tied to a Flashcards account because there is no Flashcards account.

The full local database can be exported to **JSON** and restored later. Individual decks can also be exported from their deck page.

Backups are designed to preserve the data required to reconstruct the study library independently of any external service.

This makes it possible to:

- Keep your own offline archive
- Transfer a library manually
- Restore after reinstalling
- Export a specific deck separately

---

## Privacy by design

Flashcards is designed to work entirely on-device.

- No account
- No backend
- No cloud database
- No analytics
- No advertising
- No tracking
- No runtime network requests
- No third-party SDKs
- No package dependencies

Folders, decks, cards, study progress, preferences, active sessions, and history remain local to the device unless you explicitly export them yourself.

---

## Localization

Flashcards currently supports:

- 🇫🇷 **French**
- 🇬🇧 **English**
- 🇩🇪 **German**
- 🇪🇸 **Spanish**
- **Automatic** language selection based on the device

The language can also be selected manually from Settings.

Duplicate warnings, study UI, settings, import flows, and the rest of the user-facing interface follow the selected app language.

---

## Design

Flashcards follows the current native iOS design language instead of recreating an independent component system.

The v2 visual system is built around:

- A dark interface
- Mint `#46D7A7` as the main brand/action color
- Neutral black, white, and system-gray structure
- Red for destructive actions and exact duplicate warnings
- Orange for possible duplicate warnings
- SF Symbols
- System typography
- Native navigation and forms
- Native context menus, sheets, confirmation dialogs, and alerts
- Liquid Glass controls where appropriate
- Native haptics
- Continuous rounded geometry and compact information density

Folders use neutral gray cards with mint icon surfaces. Decks use compact full-width rows with a mint deck glyph, metadata, and a subtle disclosure indicator. The same deck component is reused across Home, folder pages, and search to keep the hierarchy visually predictable.

The app icon is also stored as a layered `AppIcon.icon` bundle, allowing Apple's icon system to apply platform-native depth and material behavior.

---

## Technology

Flashcards intentionally keeps its stack small and native.

| | |
| --- | --- |
| UI | SwiftUI |
| Persistence | SwiftData |
| Language | Swift 6 |
| Platform | iOS |
| Minimum version | iOS 27.0 |
| App icon | Layered `.icon` bundle |
| Dependencies | None |
| Backend | None |
| Runtime network access | None |

All runtime functionality is implemented using Apple APIs.

---

## Project structure

```text
Flashcards/
├── AppIcon.icon/
├── Assets.xcassets/
├── Models/
├── Services/
├── Views/
│   ├── Import/
│   ├── Library/
│   ├── Settings/
│   ├── Study/
│   └── Test/
├── AppPreferences.swift
├── AppSettings.swift
├── FlashcardsApp.swift
├── L10n.swift
├── Localizable.xcstrings
└── Theme.swift
```

The project is organized around app domains and native views rather than external frameworks or architectural dependencies.

---

## Installation

### Stable releases

Stable unsigned IPA builds are available from the repository's [Releases](https://github.com/raaaton/Flashcards/releases) page.

The current major generation starts at:

```text
Flashcards-v2.0.0.ipa
```

The IPA must be signed before installation using a compatible iOS sideloading solution.

### Development builds

The latest successful build from `main` is published through the **Development Build** link near the top of this README.

Development builds are intended for testing the newest changes and may be less stable than tagged releases.

---

## Build from source

### Requirements

- macOS
- Xcode 27 or newer
- iOS 27 SDK

Clone the repository:

```bash
git clone https://github.com/raaaton/Flashcards.git
cd Flashcards
```

Open `Flashcards.xcodeproj`, select the **Flashcards** target, choose an iPhone or simulator, and build normally.

There are no package dependencies to resolve.

---

## Continuous integration

GitHub Actions is used as the project's build and release pipeline.

The workflow performs checks including:

- Offline / single-target project audit
- App icon validation
- Localization validation
- Foundation smoke tests
- Release build for `iphoneos`
- IPA structure validation
- Development artifact generation
- Automatic publication of the latest development IPA

Manual release runs additionally handle release versioning and release publication. Release numbering is driven by configurable `RELEASE_MAJOR` and `RELEASE_MINOR` repository variables, while the patch number is derived automatically from existing tags.

For manual release validation, the workflow can also build, install, and launch the app in an iOS simulator.

Release IPAs use the standard structure:

```text
Payload/
└── Flashcards.app/
```

---

## Principles

**Fast to create.**  
A new deck should take seconds to start, whether it contains one card or a pasted list of hundreds.

**Focused while studying.**  
The current card or question stays visually dominant while secondary controls get out of the way.

**Native to iOS.**  
System components, SF Symbols, navigation patterns, materials, haptics, and interactions are preferred whenever possible.

**Local first.**  
Core functionality must work without a server or internet connection.

**User-owned data.**  
The complete study library should remain exportable and usable independently of any service.

**Consistent rather than endlessly customizable.**  
The v2 visual system deliberately uses one coherent mint identity across folders, decks, study actions, and controls.

---

## Contributing

Issues are welcome, but Pull Requests are not currently accepted.

---

## License

See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Flashcards</strong><br />
  Native. Offline. Focused.
</p>
