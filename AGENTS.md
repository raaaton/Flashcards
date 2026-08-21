# AGENTS.md

Instructions for coding agents working in this repository.

Read `PROJECT.md` and the relevant source files before making non-trivial changes. `README.md` describes the product publicly; `PROJECT.md` describes the architecture and invariants; this file defines how agents should work.

## 1. Repository priorities

Preserve these invariants unless the user explicitly asks to change them:

1. Native iOS app.
2. Swift 6 + SwiftUI + SwiftData.
3. Minimum deployment target: iOS 27.0.
4. No third-party dependencies.
5. No backend.
6. No runtime network access.
7. No analytics, tracking, or advertising.
8. User data remains local and exportable.
9. Prefer Apple-native UI and interaction patterns.
10. Keep the codebase small and understandable.

Do not solve a local UI problem by introducing a framework, package, remote service, or architectural layer unless explicitly requested.

## 2. Before editing

For each task:

- inspect the current implementation instead of assuming file contents
- inspect adjacent helpers/services when behavior crosses files
- check whether persistence, backup, localization, and CI are affected
- keep the requested behavior as the scope boundary
- preserve working behavior that the user has already validated

When the current implementation is already fluid/correct except for one visual or behavioral issue, prefer the smallest targeted fix over a rewrite.

## 3. Swift / SwiftUI style

Prefer idiomatic modern Swift and SwiftUI.

- Use value-driven SwiftUI state and native controls.
- Keep views readable; extract helpers when they remove real duplication or isolate complex behavior.
- Prefer system components over custom replicas.
- Prefer semantic colors and shared theme helpers.
- Reuse `Theme`, `FolderAppearance`, `L10n`, and existing reusable views/services before adding parallel utilities.
- Use SF Symbols rather than bundled decorative icons when a suitable system symbol exists.
- Use native haptics through the existing haptic service.
- Keep animation intentional and responsive.

For Apple-like direct manipulation (drag/drop, swipe, reorder, sheets), preserve spatial continuity. Avoid duplicate drag representations, abrupt pop-outs, or animations that visually contradict the model state.

## 4. Design invariants

The app is currently dark-first and follows native iOS design language.

Maintain:

- system typography
- native navigation and sheets
- Liquid Glass where already used/appropriate
- contextual folder colors
- semantic success/error colors
- clean spacing and rounded continuous shapes
- high interaction fidelity

Unfiled has a gray library identity, but controls such as location selectors, add-card actions, bulk-add actions, and save/confirmation controls may intentionally use the app's global blue accent. Do not globally replace one semantic role with the other.

## 5. SwiftData and persistent models

Treat model changes as compatibility-sensitive.

When adding a stored property:

- prefer an additive property with a sensible default
- keep existing stores readable
- avoid destructive schema changes unless explicitly requested
- preserve stable UUIDs and relationships
- update related services and backups when the value is user-owned state

Do not rely on SwiftData relationship array order for user-visible ordering.

Current explicit ordering fields include:

- `Card.position`
- `Folder.sortOrder`

After mutations, normalize/persist ordering where required and save the `ModelContext`.

## 6. Backup compatibility

JSON backup/restore is a product invariant, not an optional extra.

If a model change affects meaningful user data:

- update the corresponding backup DTO
- export the new field
- import the new field
- decode older backups using `decodeIfPresent` or an equivalent safe default where appropriate
- preserve IDs and relationships
- update `CITests/BackupCodecSmoke.swift` when backup behavior changes

Do not casually bump the backup schema version for an additive backward-compatible field.

## 7. Localization

The app supports French and English.

For new user-facing text:

- reuse existing localization keys/helpers when possible
- add/update entries in `Localizable.xcstrings` when introducing durable UI copy
- use `L10n` helpers when a concrete localized `String` is needed
- keep pluralization/formatting logic centralized

Do not duplicate pluralization rules inside individual views when a shared helper is appropriate.

## 8. Services and domain logic

Keep reusable domain mutations in services when there is already a service boundary.

Examples:

- library mutations → `LibraryActions`
- backup/import/export → backup services/models
- text import parsing/duplicates → import services
- study state/persistence → study services
- haptics → haptic service

Do not move simple one-view behavior into a new service just for architectural symmetry.

## 9. Testing and validation

The project may be edited from non-macOS environments, so GitHub Actions is an important compilation source of truth.

Before considering a change complete:

- inspect the final diff
- ensure touched code is internally consistent
- update relevant smoke tests when logic is testable
- preserve workflow audit expectations
- check GitHub Actions status when available

Do not claim an Xcode build was run if it was not.

`CITests/` should stay lightweight and deterministic.

## 10. CI and workflow constraints

`.github/workflows/build-ipa.yml` is both a build workflow and a repository contract. It contains audits that intentionally reject certain architecture/dependency/network changes.

Do not weaken or remove CI audit checks merely to make a change pass unless the user explicitly wants the underlying invariant changed.

Normal feature/fix work should not manually edit release metadata.

Do not manually bump:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`
- release tags
- README development IPA version links

The release workflow owns versioned release updates.

## 11. Git behavior

Use Conventional Commit-style messages consistent with the repository, for example:

- `feat: add drag-and-drop folder reordering`
- `fix: refine folder drag-and-drop visuals`
- `docs: add project and agent guidance`
- `refactor: simplify ...`
- `chore: ...`

Prefer one logical final commit for one requested change.

When tool limitations require multiple temporary commits, squash them before finishing if it is safe and authorized.

Do **not** rewrite published history, force-update `main`, rename existing commits, or force-push unless the user explicitly requests history rewriting or it is necessary to clean up temporary commits created during the same agent operation.

Do not create temporary branches unless they materially reduce risk. If you create one, clean it up when possible after the final result is on `main`.

Before writing to `main`, verify that its head has not unexpectedly moved when concurrent changes are plausible.

## 12. Scope discipline

Do not opportunistically refactor unrelated code.

Allowed incidental fixes are limited to things necessary for the requested change, such as:

- compilation fixes caused by the change
- directly adjacent consistency fixes
- tests/backup/localization required by the feature

If you notice unrelated debt, leave it alone unless the user asks.

## 13. Comments

Prefer self-explanatory code.

Use comments for:

- non-obvious platform behavior
- compatibility constraints
- intentional timing/animation decisions
- invariants that future maintainers might otherwise "simplify" incorrectly

Avoid comments that merely restate the next line of code.

## 14. Definition of done

A change is complete when:

- the requested behavior is implemented
- the implementation matches existing native design patterns
- persistence remains correct
- backup compatibility is preserved when relevant
- localization is handled when relevant
- tests/CI expectations are updated when relevant
- the final Git diff is scoped
- the commit message accurately describes the change
- the result is pushed to the intended branch

When reporting completion, state what changed and any validation limitation that actually exists. Do not invent successful builds or tests.
