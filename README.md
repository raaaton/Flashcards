![header](https://github.com/user-attachments/assets/03162523-f774-46c7-8748-eeb635d48c92)

<p align="center">
  <img alt="release" src="https://img.shields.io/github/v/release/raaaton/Kavi" />
  <img alt="stars" src="https://img.shields.io/github/stars/raaaton/Kavi" />
  <img alt="forks" src="https://img.shields.io/github/forks/raaaton/Kavi" />
  <img alt="issues" src="https://img.shields.io/github/issues/raaaton/Kavi" />
</p>

# Kavi

**Kavi** is a native, local-first iOS study app built for fast card creation, focused revision, and full ownership of your data.

It is written entirely with **SwiftUI**, **SwiftData**, and Apple system APIs. There is no account, backend, analytics SDK, advertising layer, or in-app runtime network dependency.

Kavi 3.0.0 is the current major generation, combining the monochrome-first visual system, rebuilt Home experience, compact deck rows, improved duplicate detection, external-AI-assisted deck creation, configurable Home sections, expanded localization, and a consistent Apple-native interaction model throughout the app.

<p align="center">
  <img
    width="31%"
    alt="Home showing Resume, Recent and the redesigned Folder tiles"
    src="https://github.com/user-attachments/assets/112e598b-878e-4513-933e-8be03c065dca"
  />
  <img
    width="31%"
    alt="Deck study hub showing progress, Flashcards and Test modes, and the deck’s card list"
    src="https://github.com/user-attachments/assets/32fe9797-3c75-4d96-b0e3-71edef84078e"
  />
  <img
    width="31%"
    alt="Flashcards study screen with a card semi-flipped to its &quot;I knew it&quot; edge"
    src="https://github.com/user-attachments/assets/1e7339ac-afb6-4523-9707-c854f1f60143"
  />
</p>

---

## Distribution

Prebuilt IPA files are not distributed from this public repository. The source remains available for local builds and review.

---

## Version 3

The current major generation is a major visual and interaction refresh rather than a simple coat of paint.

- Monochrome-first app-wide identity with mint `#46D7A7` reserved as a selective brand/action signature
- New layered app icon using Apple's `.icon` format
- Rebuilt Home hierarchy with **Resume**, **Recent**, **Pinned**, and **Folders**
- Optional Home sections configurable from Settings
- Uniform folder design with SF Symbols on neutral icon surfaces
- Compact, full-width deck rows instead of the previous card grid treatment
- Matching deck presentation between Home, search, and folder pages
- Expanded deck context menus with pin, edit, duplicate, and delete actions
- New deck creation choice between **Create with AI — Recommended** and **Create manually**
- Independent test creation choice: generate questions with AI, author them manually, or keep generating them from flashcards
- External AI handoff for ChatGPT, Claude, and Gemini without an AI API or backend
- Improved first-deck onboarding
- More consistent native sheets, menus, alerts, haptics, and Liquid Glass controls
- Duplicate detection extended beyond bulk import to normal card creation and editing
- French, English, German, and Spanish localization

<p align="center">
  <img
    width="48%"
    alt="Home showing Resume, Recent and the redesigned Folder tiles"
    src="https://github.com/user-attachments/assets/112e598b-878e-4513-933e-8be03c065dca"
  />
  <img
    width="48%"
    alt="A folder page showing the new compact full-width Deck rows"
    src="https://github.com/user-attachments/assets/afbe79f6-0cd8-4edb-8d9b-ceae0b5d1a76"
  />
</p>

---

## Features

### Organize your library

Kavi uses a simple hierarchy:

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

The current interface intentionally removes per-folder accent colors from the visible design. Folders and deck glyphs use neutral surfaces and white symbols so the library remains visually quiet; mint is saved for primary actions, progress, selected states, and small brand details.

---

### Create cards quickly

Cards can be created one at a time, generated through an external AI you already use, or pasted in large batches.

- Add and edit cards individually
- Start every new deck by choosing its name
- Choose how to create the flashcards and how to create the Multiple Choice / True-False questions independently
- Create a new deck with several initial cards in the manual flow
- Add more card editors while creating a deck
- Delete draft cards before saving
- Select multiple existing cards for bulk actions
- Star or unstar cards
- Delete selected cards
- Move selected cards to another deck
- Copy selected cards to another deck
- Reorder cards inside a deck

#### Create with AI

Kavi can prepare a deck using **ChatGPT**, **Claude**, or **Gemini** without embedding an AI model or calling an AI API.

The flow is deliberately user-controlled:

1. Name the deck, choose how to create its flashcards, then choose how to create its tests.
2. When AI is selected, pick Claude, ChatGPT, or Gemini.
3. Kavi generates the appropriate flashcards-only, flashcards-and-tests, or tests-only prompt and copies it to the clipboard.
4. Kavi opens the provider's native app. If the prompt is not already present, paste it into the composer, attach your notes, images, or documents, and send it.
5. The AI returns a JSON block containing the requested flashcards and/or test questions.
6. Copy that JSON block and return to Kavi.
7. Tap **Paste from ChatGPT / Claude / Gemini** to parse it locally.
8. Review or edit the cards and authored questions, resolve duplicate warnings, then create the deck in one local SwiftData save.

Clipboard copy remains the robust fallback, and the provider itself handles any document upload outside Kavi. There is no Kavi account, AI subscription, server-side proxy, model token cost, or AI SDK in the app.

#### Duplicate detection

Duplicate detection is available during normal creation as well as bulk import.

Kavi distinguishes between:

- **Exact duplicate** — same normalized term and definition
- **Possible duplicate** — same normalized term with a different definition

Exact duplicates use semantic red feedback, while possible duplicates use orange warnings. Before saving, the app can warn you and let you continue deliberately instead of silently creating duplicate content.

This applies when:

- Creating cards inside a new deck, including cards returned by the external AI flow
- Adding a single card to an existing deck
- Editing an existing card
- Using Bulk Add / Bulk Import

When editing a card, the card itself is excluded from duplicate comparison.

<p align="center">
  <img
    width="48%"
    alt="New Deck screen with an Exact duplicate warning visible"
    src="https://github.com/user-attachments/assets/3d77721f-b990-438c-844a-e77761390335"
  />
  <img
    width="48%"
    alt="New Deck screen with an Exact duplicate popup warning visible"
    src="https://github.com/user-attachments/assets/4af08ef7-e16d-4939-a382-2cb2a853ba16"
  />
</p>

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

## Study

Every deck has a dedicated study hub that brings progress, study modes, and card management together in one place.

From here, you can see your current deck progress, launch either **Flashcards** or **Test**, and review or edit the cards before starting a session.

The goal is to keep everything related to a deck immediately accessible without adding extra navigation or setup screens.

<p align="center">
  <img
    width="40%"
    alt="Deck study hub showing progress, Flashcards and Test modes, and the deck’s card list"
    src="https://github.com/user-attachments/assets/32fe9797-3c75-4d96-b0e3-71edef84078e"
  />
</p>

### With Flashcards

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

<p align="center">
  <img
    width="31%"
    alt="Flashcards study hub"
    src="https://github.com/user-attachments/assets/931c3016-fa78-4354-b37f-17010db35b89"
  />
  <img
    width="31%"
    alt="Flashcards study screen with a card flipped to its answer side"
    src="https://github.com/user-attachments/assets/cfcdfde6-cffd-4b2f-96e4-e594cc1a1ee5"
  />
  <img
    width="31%"
    alt="Flashcards study screen with a card semi-flipped to its &quot;I knew it&quot; edge"
    src="https://github.com/user-attachments/assets/a14d93f6-b428-4576-8f80-80764f30a357"
  />
</p>

---

### Test yourself

The same deck can also run mixed tests instead of swipe-based flashcards. Multiple Choice and True / False questions can be generated from flashcards as before, authored manually, or prepared through the external AI handoff and reviewed before saving.

Supported question formats:

- **Multiple Choice**
- **True / False**
- **Written Answer**

Custom questions remain linked to a source flashcard, so starred-only filtering and card statistics continue to work. Direction affects generated written answers only; custom Multiple Choice and True / False wording stays fixed. Shuffle and global 10/20/All limits apply across the enabled question pools.

Written answers can be submitted directly from the keyboard, while every test run stays completely on-device.

<p align="center">
  <img
    width="23%"
    alt="Test study hub"
    src="https://github.com/user-attachments/assets/057499d6-e397-46fa-8752-66ad4aa99baf"
  />
  <img
    width="23%"
    alt="Test study screen with a Multiple Choice question answered correctly"
    src="https://github.com/user-attachments/assets/ec015a26-6d64-4639-ae9c-306b73c5027f"
  />
  <img
    width="23%"
    alt="Test study screen with a True or False question answered correctly"
    src="https://github.com/user-attachments/assets/52c24cee-aede-4708-a089-f0b397290ba1"
  />
  <img
    width="23%"
    alt="Test study screen with a Type question answered incorrectly"
    src="https://github.com/user-attachments/assets/e27e74e7-fe1a-4653-b7ff-f099e55bf660"
  />
</p>

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

The visual identity itself is intentionally fixed rather than user-configurable: the interface is overwhelmingly neutral, mint remains the app's selective brand/action accent, and red/orange remain reserved for semantic warnings and destructive states.

---

## Backup & restore

Your data is not tied to a Kavi account because there is no Kavi account.

The full local database can be exported to **JSON** and restored later. Individual decks can also be exported from their deck page.

New backups use schema version 2 and preserve authored test configuration as readable structured JSON. Existing schema-v1 backups remain importable and restore decks with the historical generate-from-flashcards test behavior.

This makes it possible to:

- Keep your own offline archive
- Transfer a library manually
- Restore after reinstalling
- Export a specific deck separately

---

## Privacy by design

Kavi is designed so its own data and parsing workflows remain on-device.

- No account
- No backend
- No cloud database
- No analytics
- No advertising
- No tracking
- No in-app runtime network requests
- No third-party SDKs
- No package dependencies
- No embedded AI model or AI API

Folders, decks, cards, study progress, preferences, active sessions, and history remain local to the device unless you explicitly export them yourself.

The optional **Create with AI** flow is an explicit external handoff: Kavi copies a generated prompt and opens the ChatGPT, Claude, or Gemini app you selected. Any internet access, document upload, account state, and AI processing happen in that provider's app or website, not inside Kavi. The JSON response is only parsed after you explicitly copy it back into Kavi.

---

## Localization

Kavi currently supports:

- 🇫🇷 **French**
- 🇬🇧 **English**
- 🇩🇪 **German**
- 🇪🇸 **Spanish**
- **Automatic** language selection based on the device

The language can also be selected manually from Settings.

Duplicate warnings, study UI, settings, import flows, AI handoff copy, and the rest of the user-facing interface follow the selected app language.

---

## Design

Kavi follows the current native iOS design language instead of recreating an independent component system.

The current visual system is built around:

- A dark interface
- Roughly 90–95% neutral black, white, system-gray, and material structure
- Mint `#46D7A7` as a selective brand/action signature rather than a repeated surface color
- Mint reserved primarily for primary CTAs, progress, selected states, success, and small branding details
- Red for destructive actions and exact duplicate warnings
- Orange for possible duplicate warnings
- SF Symbols
- System typography
- Native navigation and forms
- Native context menus, sheets, confirmation dialogs, and alerts
- Liquid Glass controls where appropriate
- Native haptics
- Continuous rounded geometry and compact information density

Folders use neutral gray cards with white symbols on neutral icon surfaces. Decks use compact full-width rows with the same quiet icon treatment, metadata, and a subtle disclosure indicator. Study-mode tiles are neutral rather than large mint blocks, while progress and true primary actions retain the mint signature. The same deck component is reused across Home, folder pages, and search to keep the hierarchy visually predictable.

The app icon is also stored as a layered `AppIcon.icon` bundle, allowing Apple's icon system to apply platform-native depth and material behavior.

---

## Technology

Kavi intentionally keeps its stack small and native.

| | |
| --- | --- |
| UI | SwiftUI |
| Persistence | SwiftData |
| Language | Swift 6 |
| Platform | iOS |
| Minimum version | iOS 26.0 |
| App icon | Layered `.icon` bundle |
| Dependencies | None |
| Backend | None |
| In-app runtime network access | None |
| AI integration | External user-controlled handoff only |

All in-app runtime functionality is implemented using Apple APIs.

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

## Build from source

### Requirements

- macOS
- Xcode 27 or newer
- iOS 27 SDK

Clone the repository:

```bash
git clone https://github.com/raaaton/Kavi.git
cd Kavi
```

Open `Flashcards.xcodeproj`, select the app target, choose an iPhone or simulator, and build normally.

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
- Identity-free ad hoc signing for downstream sideload re-signing
- IPA structure validation
- Private IPA packaging
- A normal, versioned private GitHub release for every push to `main`

Each private release uses a unique build tag such as `v3.0.0-build.213` and an asset such as `Kavi-3.0.0-build.213.ipa`. No IPA is uploaded as a public Actions artifact or public release asset. Manual release runs additionally handle release versioning and publish public release metadata without attaching the IPA. Release numbering is driven by configurable `RELEASE_MAJOR` and `RELEASE_MINOR` repository variables, while the patch number is derived automatically from existing tags.

For manual release validation, the workflow can also build, install, and launch the app in an iOS simulator.

Release IPAs use the standard structure:

```text
Payload/
└── Kavi.app/
```

---

## Principles

**Fast to create.**  
A new deck should take seconds to start, whether it is entered manually, generated through an external AI handoff, or imported from a pasted list.

**Focused while studying.**  
The current card or question stays visually dominant while secondary controls get out of the way.

**Native to iOS.**  
System components, SF Symbols, navigation patterns, materials, haptics, and interactions are preferred whenever possible.

**Local first.**  
Core functionality must work without a server or internet connection. Optional external-provider handoffs remain explicit and never become a dependency for manual creation, import, study, backup, or restore.

**User-owned data.**  
The complete study library should remain exportable and usable independently of any service.

**Consistent rather than endlessly customizable.**  
The current visual system deliberately uses one coherent monochrome foundation with a restrained mint signature instead of tinting every folder, deck, action, and surface.

---

## Contributing

Issues are welcome, but Pull Requests are not currently accepted.

---

## License

See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Kavi</strong><br />
  Native. Offline. Focused.
</p>
