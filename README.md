![header](https://github.com/user-attachments/assets/f29c4273-db88-47d5-bc5a-139ce66f180f)

<p align="center">
  <img alt="release" src="https://img.shields.io/github/v/release/raaaton/Flashcards" />
  <img alt="stars" src="https://img.shields.io/github/stars/raaaton/Flashcards" />
  <img alt="forks" src="https://img.shields.io/github/forks/raaaton/Flashcards" />
  <img alt="issues" src="https://img.shields.io/github/issues/raaaton/Flashcards" />
  <img alt="downloads" src="https://img.shields.io/github/downloads/raaaton/Flashcards/total" />
</p>

# Flashcards

Native iOS flashcards application, fully local and offline. It lets you manage folders, decks, and cards, import hundreds of cards from text, study using rounds, generate tests, and back up the entire database as JSON.

## Features

* SwiftUI, SwiftData, and Apple APIs only
* iOS 27.0 minimum, French interface with dark mode
* no account, server, tracking, purchases, or network requests
* bulk import with live preview and configurable delimiters
* Flashcards and Test modes (multiple choice, True/False, written answers)
* merge-based JSON export/import

## Install the IPA

1. Open the [latest Release](https://github.com/raaaton/Flashcards/releases/latest).
2. Download `Flashcards.ipa`.
3. Import the file into SideStore or AltStore (not Altstore PAL) on your iPhone.

The IPA is unsigned. SideStore and AltStore handle signing and renewal using the user's Apple ID.

## Build

Every push to `main` uses the GitHub Actions `xcode-27` runner, builds for `iphoneos` without signing, runs smoke tests, and publishes a Release containing the IPA.
