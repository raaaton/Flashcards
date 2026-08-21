![header](https://github.com/user-attachments/assets/f29c4273-db88-47d5-bc5a-139ce66f180f)

<p align="center">
  <img alt="release" src="https://img.shields.io/github/v/release/raaaton/Flashcards" />
  <img alt="stars" src="https://img.shields.io/github/stars/raaaton/Flashcards" />
  <img alt="forks" src="https://img.shields.io/github/forks/raaaton/Flashcards" />
  <img alt="issues" src="https://img.shields.io/github/issues/raaaton/Flashcards" />
</p>

# Flashcards

Native iOS flashcards app focused on fast creation, distraction-free studying, and complete offline ownership of your data.<br />
Built entirely with SwiftUI, SwiftData, Apple system APIs and ❤️.

---

## Development Build

<!-- DEV_IPA_START -->
[⬇️ **Download latest development IPA**](https://github.com/raaaton/Flashcards/releases/download/dev/Flashcards-v1.10.4.ipa)
<!-- DEV_IPA_END -->

> Built automatically from the latest commit on `main`. Development builds may be unstable.

---

## Preview

<p align="center">
  <img width="197" height="426" src="https://github.com/user-attachments/assets/cfd723bc-fba5-4365-be3d-7612562d3db7" />
  <img width="197" height="426" src="https://github.com/user-attachments/assets/5f040034-350c-4cf0-84f7-7f4d2de66e02" />
  <img width="197" height="426" src="https://github.com/user-attachments/assets/284ad7da-6d84-4712-881a-7d12dfd04d99" />
</p>

<p align="center">
  <sub>Organize your subjects, create decks, and study without leaving the app.</sub>
</p>

---

## Features

### Organize

- Create folders with custom colors and SF Symbols
- Create and manage multiple decks inside each folder
- Pin important decks for quick access
- Quickly reopen recently used decks
- Search folders, decks, terms, and definitions
- Optional folder-scoped search
- Move or copy cards between decks

### Create cards

- Add and edit cards individually
- Select and edit multiple cards at once
- Star important cards for focused study
- Detect potential duplicates while creating or importing cards
- Import large sets of cards from plain text
- Configure separators when importing
- Preview imported cards before saving
- Paste formatted card lists directly into the importer

### Study with Flashcards

- Study term → definition or definition → term
- Optional shuffle
- Study starred cards only
- Choose a session size
- Swipe right for **Correct**
- Swipe left for **Review**
- Flip cards with an animated 3D transition
- Undo previous judgments
- Resume unfinished sessions
- Review mistakes in a separate session
- Track mastered cards and deck progress
- Completion feedback with native haptics and celebrations

<img width="197" height="426" src="https://github.com/user-attachments/assets/f2838f76-6fc5-4eaf-b1a2-aea545b55d88" />
<img width="197" height="426" src="https://github.com/user-attachments/assets/5f040034-350c-4cf0-84f7-7f4d2de66e02" />


### Test yourself

Create mixed tests from the same cards using several question formats:

- Multiple choice
- True / False
- Written answer

Tests can use the same direction, shuffle, starred-only, and session-size preferences as Flashcards.

  <img width="197" height="426" src="https://github.com/user-attachments/assets/b4336570-41d8-4a5d-8fd6-ecd5b4fa7aae" />
  <img width="197" height="426" src="https://github.com/user-attachments/assets/2164632f-44cf-4960-973b-8449872934e7" />


### Study history

Completed study sessions are stored locally with:

- Study mode
- Number of cards
- Correct answers
- Incorrect answers
- Completion date

This makes it easy to see recent activity without requiring an account or online service.

---

## Privacy by design

Flashcards is designed to work entirely on-device.

- No account
- No backend
- No analytics
- No advertising
- No tracking
- No external database
- No runtime network requests
- No third-party SDKs

Your folders, decks, cards, progress, and study history remain stored locally on your device.

---

## Backup & restore

The complete database can be exported as JSON and restored later.

Backups include the data required to recreate your library, making it possible to keep an independent copy of your flashcards without relying on a cloud account.

---

## Localization

Flashcards currently supports:

- 🇫🇷 French
- 🇬🇧 English
- Automatic language selection based on the device

The language can also be selected manually from Settings.

---

## Technology

Flashcards intentionally keeps its stack small and native.

| | |
| --- | --- |
| UI | SwiftUI |
| Persistence | SwiftData |
| Language | Swift |
| Platform | iOS |
| Minimum version | iOS 27.0 |
| Dependencies | None |
| Backend | None |
| Network access | None |

All runtime functionality is implemented using Apple APIs.

---

## Project structure

```text
Flashcards/
├── Models/
├── Views/
│   ├── Import/
│   ├── Library/
│   ├── Study/
│   └── Test/
├── Services/
├── Components/
├── Assets.xcassets/
├── Localizable.xcstrings
└── FlashcardsApp.swift
````

The application is split around its main domains rather than relying on external frameworks or architectural dependencies.

---

## Installation

### Stable releases

Stable unsigned IPA builds are available from the repository's [Releases](https://github.com/raaaton/Flashcards/releases) page.

Each stable release is versioned individually, for example:

`Flashcards-v1.8.1.ipa`

### Development builds

The latest build from `main` is always available on top of this README.

Development builds are generated automatically and may contain unfinished or unstable changes.

The IPA must be signed before installation using a compatible iOS sideloading solution.

## Build from source

### Requirements

* macOS
* Xcode 27 or newer
* iOS 27 SDK

Clone the repository:

```bash
git clone https://github.com/raaaton/Flashcards.git
cd Flashcards
```

Open the Xcode project, select the **Flashcards** target, choose an iPhone or simulator, and build normally.

There are no package dependencies to resolve.

---

## Continuous integration

Every relevant build is verified using GitHub Actions on an Xcode 27 environment.

The workflow checks the project before packaging a release, including:

* Source and project configuration audits
* Release build for `iphoneos`
* Simulator build
* Simulator installation and launch
* Automated test harnesses
* IPA structure validation
* Release artifact generation

Release IPAs use the standard structure:

```text
Payload/
└── Flashcards.app/
```

This repository's CI is also the source of truth for compilation when development is performed outside macOS.

---

## Design

Flashcards follows the native iOS design language instead of recreating its own component system.

The interface makes extensive use of:

* SwiftUI navigation
* Liquid Glass controls
* SF Symbols
* Native sheets, menus, alerts, and pickers
* Contextual folder colors
* Semantic green/red feedback
* System typography
* Native haptics

The app is currently designed around a dark interface.

---

## Principles

Flashcards is built around a few intentionally simple ideas:

**Fast to use.**
Creating a deck should take seconds, including when importing hundreds of cards.

**Focused while studying.**
Study screens prioritize the current card or question rather than surrounding controls.

**Native to iOS.**
System components and interactions are preferred whenever possible.

**Local first.**
Core functionality must not depend on a server or internet connection.

**User-owned data.**
Your study library should remain usable and exportable independently of any service.

---

## Contributing

Issues are welcome, but not Pull Requests.

---

## License

See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Flashcards</strong><br>
  Native. Offline. Focused.
</p>
