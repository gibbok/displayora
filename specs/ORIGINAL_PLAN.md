# Displayora Standalone Specification Suite — Original Plan

This document preserves the approved plan that governs this repository. It is
the durable source of intent when later specifications or implementations need
to resolve ambiguity.

## Product

**Displayora — Your displays, made simple.**

Displayora is a macOS 13+ menu-bar application for Intel Macs only. It uses a
small menu-bar popover and a separate Settings window, has no
permanent Dock icon, and is distributed directly as a notarized DMG using the
bundle identifier `com.displayora.Displayora`.

The platform automatically chooses the best reliable display-control
mechanism. User-facing features are optional, independently implementable
SwiftPM modules. A build may include any subset of optional features without
leaving placeholders, shortcuts, settings, imports, or other broken UI behind.

## Approved Architecture

Specifications 01–03 define the required platform. Optional specifications
04–10 depend only on that platform and never on sibling features. Every
optional module conforms to `DisplayoraFeature` and registers controls,
settings, capabilities, and commands through `FeatureRegistry`.

Shared color-transform coordination belongs to the platform so Brightness,
Contrast, and Night Comfort remain independent. Keyboard Controls discovers
installed actions through the command registry. Every feature has an isolated
`make verify-feature FEATURE=<name>` path that builds and tests the feature and
composes it in a test host.

The project is Swift 6 and SwiftPM based under `app/`. Development and release
workflows are terminal-only: no `.xcodeproj`, Xcode GUI, or `xcodebuild`.
Intel-only output is made from a single `x86_64` build.

## Specification Sequence

| ID | Specification | Classification | Dependencies |
|---|---|---|---|
| 01 | Project Foundation | Required platform | None |
| 02 | Menu-Bar Shell and Onboarding | Required platform | 01 |
| 03 | Display Platform and Capabilities | Required platform | 01, 02 |
| 04 | Brightness | Optional standalone feature | 01, 02, 03 |
| 05 | Contrast | Optional standalone feature | 01, 02, 03 |
| 06 | Volume and Mute | Optional standalone feature | 01, 02, 03 |
| 07 | Resolution Selector | Optional standalone feature | 01, 02, 03 |
| 08 | Keyboard Controls | Optional standalone feature | 01, 02, 03 |
| 09 | Disable and Re-enable Display | Optional standalone feature | 01, 02, 03 |
| 10 | Night Comfort | Optional standalone feature | 01, 02, 03 |
| 11 | Direct Distribution and Release | Required release | 01, 02, 03 |

## Feature Scope

### 01 — Project Foundation

Create the SwiftPM project, SwiftUI menu-bar executable, Settings scene,
feature registry, isolated feature test host, terminal workflow, Intel-only app
assembly, ad-hoc signing, warning-free builds, and strict concurrency checks.

### 02 — Menu-Bar Shell and Onboarding

Define the minimal popover and Settings experience, shared feature
contribution interfaces, empty and single-feature compositions, first-run,
loading, no-display, error, accessibility, and launch-at-login behavior.

### 03 — Display Platform and Capabilities

Define stable discovery, hot-plugging, sleep/wake, capability probing,
hardware/software adapters and fakes, the shared color-transform coordinator,
and hardware, software-fallback, temporary-failure, and unsupported states.

### 04 — Brightness

Provide independent DDC/CI brightness adjustment with coordinated software
dimming fallback, including HDR, debounce, reconnect, and restoration.

### 05 — Contrast

Provide independent DDC/CI contrast and a safe software color-curve fallback,
with clipping prevention and shared-pipeline composition.

### 06 — Volume and Mute

Use monitor DDC volume or a confidently associated writable Core Audio output.
Hide the feature when neither mechanism is reliable.

### 07 — Resolution Selector

Use Core Graphics to present HiDPI, resolution, refresh rate, and the current
mode clearly. Changes require a fifteen-second confirmation and automatic
revert.

### 08 — Keyboard Controls

Route commands independently. Native media keys are optional and use
Accessibility onboarding; configurable shortcuts remain available without
Accessibility permission. Only installed features contribute commands.

### 09 — Disable and Re-enable Display

Use an isolated, runtime-checked, LightsOut-inspired
`CGSConfigureDisplayEnabled` adapter with `.forAppOnly`, final-display
protection, timed recovery, and termination restoration. Supply a
mirror-plus-gamma fallback and verify natively on Intel.

### 10 — Night Comfort

Provide manual and fixed-schedule color warmth without Location permission.
The feature works without Brightness or Contrast and handles overnight
schedules, timezone changes, sleep/wake, HDR, and restoration.

### 11 — Direct Distribution and Release

Release any selected feature subset as an Intel-only `.app` and downloadable
DMG. Apply Developer ID signing, Hardened Runtime, notarization, and stapling;
run native Intel smoke tests; and publish a manifest listing
included and omitted features. No gate depends on an intentionally omitted
feature.

## Required Specification Contract

Each numbered specification contains metadata, dependencies, goal, non-goals,
classification, a Mermaid UX or state diagram, stable requirement IDs,
interfaces and data flow, novice-focused UI behavior, accessibility,
permissions, failures, recovery, Given/When/Then acceptance criteria mapped to
requirements and tests, exact automated and manual verification, Intel
considerations, standalone and omission behavior, and the
mandatory code-quality and automatic-review gate.

Each author records two self-review and revision passes. A finished
specification contains no unresolved `TODO`, `TBD`, open question, or deferred
implementation choice.

## Sequential Authoring Workflow

For each tracker row, a fresh Codex author works only on that specification
and its tracker entry, performs two documented self-review passes, and returns
it to the coordinator. The coordinator runs:

```sh
make check-specs
git diff --check
```

The coordinator commits and opens a draft pull request before another
specification starts. Documentation commits use
`docs(spec-NN): define <feature>`. Every numbered specification has its own
draft pull request for human review. The pull request description begins with
a concise, human-readable summary of the outcome and explains the important
decisions, why they matter, review focus, dependencies, and validation without
requiring the reviewer to decode requirement IDs.

When earlier specification pull requests have not merged yet, later pull
requests may be stacked on the immediately preceding specification branch so
each review contains exactly one specification diff. The coordinator retargets
or rebases the next pull request onto `main` as its predecessor merges.

## Mandatory Implementation Review and Repair

Every implementation specification requires this gate:

1. One Codex implementation agent implements exactly one specification and
   runs its required checks.
2. Before commit, a different Codex review agent examines the specification,
   complete working-tree diff, changed tests, relevant shared interfaces, and
   all build, test, formatting, and architecture results.
3. The reviewer writes `specs/reviews/NN-<feature>-review.md` with the review
   round, blocking and non-blocking findings, affected requirements and files,
   required corrections, and validation results.
4. Codex automatically fixes every in-scope blocking finding and every
   non-blocking readability, idiomatic Swift, safety, accessibility, or
   maintainability finding that does not broaden scope.
5. Codex never obtains approval by weakening tests or acceptance criteria,
   suppressing warnings, hiding errors, or broadening exclusions.
6. Codex reruns focused checks and the full regression suite. The independent
   reviewer then reviews the updated diff again.
7. Review and repair continue until no blocking finding remains, every
   acceptance criterion passes, and the reviewer records `Approved`.
8. A finding that needs a product decision or specification change sets the
   implementation to `Blocked`; Codex does not invent broader behavior.
9. Only an approved implementation may be marked `Verified` and committed.

Normally the implementation, automatic fixes, final review report, and tracker
update are one `feat(spec-NN): implement <feature>` commit. A later
`fix(spec-NN): address approved review findings` is reserved for unavoidable
post-commit corrections.

## Swift Quality Bar

Implementations use straightforward, idiomatic Swift 6; clear names; focused
types and functions; value types by default; and protocols only at meaningful
system or testing boundaries. Declarative SwiftUI views contain no hardware or
business logic. UI state is `@MainActor`; values crossing concurrency
boundaries are safely `Sendable`.

Errors are explicit, typed, and recoverable. `try!`, unexplained force unwraps,
silent error suppression, crash-based control flow, premature abstraction,
unnecessary generic layers, oversized view models, and sibling-feature
coupling are prohibited. Private APIs are isolated and availability checked.
Comments explain intent and API hazards. Builds are warning-free and pass
formatting, focused tests, regression tests, and strict concurrency checks.

## Locked Decisions

- Minimum platform: macOS 13 on Intel (`x86_64`) only.
- UI: menu-bar popover plus a separate Settings window, no permanent Dock icon.
- Distribution: direct notarized DMG.
- Bundle identifier: `com.displayora.Displayora`.
- Control selection: automatically use the best reliable mechanism.
- Private display API: `CGSConfigureDisplayEnabled` only through an isolated
  adapter.
- Keyboard: optional native media keys plus configurable shortcuts.
- Night Comfort: manual control and fixed schedules, no Location permission.
- Features may be independently implemented, deferred, or omitted.
- Every implementation receives independent Codex review and automatic repair
  until approved.
- Specifications and approved implementations are committed one at a time.

## Decision Log

| Date | Decision |
|---|---|
| 2026-07-28 | Approved the standalone feature architecture and sequence above. |
| 2026-07-28 | Required independent Codex implementation review with automatic repair before `Verified`. |
| 2026-07-28 | Locked terminal-only SwiftPM development and direct notarized DMG distribution. |
| 2026-07-28 | Required one human-reviewed draft pull request per numbered specification, with a plain-language summary in its description; workflow changes follow the same draft-PR practice. |
