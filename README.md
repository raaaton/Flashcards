# Flashcards

Application iOS native de flashcards, entièrement locale et hors ligne. Elle permet de gérer des dossiers, decks et cartes, d’importer plusieurs centaines de cartes depuis du texte, d’étudier par rounds, de générer des tests et de sauvegarder la base en JSON.

## Caractéristiques

- SwiftUI, SwiftData et APIs Apple uniquement
- iOS 27.0 minimum, interface française en dark mode
- aucun compte, serveur, tracking, achat ou appel réseau
- import en masse avec aperçu et délimiteurs configurables
- modes Flashcards et Test (QCM, Vrai/Faux, réponse écrite)
- export/import JSON fusionnel

## Installer l’IPA

1. Ouvrir la [dernière Release](https://github.com/raaaton/Flashcards/releases/latest).
2. Télécharger `Flashcards.ipa`.
3. Importer le fichier dans SideStore sur l’iPhone.

L’IPA est non signée. SideStore gère la signature et son renouvellement avec l’identifiant Apple de l’utilisateur.

## Build

Chaque push sur `main` utilise le runner GitHub Actions `xcode-27`, compile pour `iphoneos` sans signature, effectue les smoke tests et publie une Release contenant l’IPA.
