# NN — Feature Name

## Metadata

| Field | Value |
|---|---|
| ID | `NN` |
| Classification | Required platform / Optional standalone / Required release |
| Specification status | Drafting |
| Implementation status | Not started |
| Dependencies | Explicit specification IDs or None |

## Goal

State the user-visible and architectural outcome.

## Non-Goals

List behavior deliberately outside this specification. Resolve scope; do not
leave open questions.

## User Experience and States

Describe novice-friendly labels, feedback, loading, empty, unsupported, error,
and recovery behavior.

```mermaid
stateDiagram-v2
    [*] --> Available
    Available --> Recovering: recoverable failure
    Recovering --> Available: retry succeeds
```

## Requirements

Use stable IDs such as `DORA-NN-001`. Include accessibility, permissions,
failure/recovery, Intel/Apple Silicon, standalone verification, and omission.

## Interfaces and Data Flow

Name module boundaries, public types, ownership, concurrency isolation, and
the direction of data. Optional features may depend only on Specifications
01–03 and external system frameworks, never sibling features.

## Failure and Recovery

Define typed failures, user feedback, bounded retry/revert behavior, state
restoration, and crash/termination considerations.

## Accessibility and Permissions

Define labels, keyboard and VoiceOver behavior, contrast/motion needs,
permission timing, denial, and revocation.

## Platform Considerations

Explain macOS 13+, Intel, Apple Silicon, HDR, sleep/wake, hot-plug, and private
API differences that apply.

## Standalone and Omission Behavior

State how `make verify-feature FEATURE=<name>` builds, tests, and composes the
feature alone. State precisely what is absent when the feature is omitted.

## Acceptance Criteria and Traceability

Every requirement maps to a Given/When/Then criterion and an automated or
manual test identifier.

| Criterion | Requirements | Given / When / Then | Verification |
|---|---|---|---|
| `AC-NN-01` | `DORA-NN-001` | Given … When … Then … | `TEST-NN-01` |

## Verification

List exact automated commands and exact manual procedures. Include focused
tests, full regression, formatting, architecture, strict concurrency,
standalone composition, omission, and native Intel and Apple Silicon evidence
where hardware behavior is involved.

## Code Quality and Automatic Review

Implementation must comply with [CODE_REVIEW.md](CODE_REVIEW.md). It uses
idiomatic, straightforward Swift 6; clear names and focused types/functions;
value types by default; protocols only at meaningful boundaries; declarative
SwiftUI; `@MainActor` UI state; safe `Sendable` values; typed recoverable
errors; and isolated, availability-checked private APIs. It prohibits
premature abstraction, unnecessary generics, oversized view models,
sibling-feature coupling, `try!`, unexplained force unwraps, silent error
suppression, crash-based control flow, and warning suppression.

Before commit, a different Codex reviewer examines the specification, complete
diff, tests, shared interfaces, and all validation results and writes
`specs/reviews/NN-<feature>-review.md`. Codex automatically repairs all
in-scope blocking findings and all scope-preserving non-blocking readability,
idiomatic Swift, safety, accessibility, and maintainability findings, then
reruns focused and full-regression checks. Tests and acceptance criteria must
not be weakened, warnings or errors hidden, or exclusions broadened.

Review and repair repeat until all acceptance criteria pass, no blocking
findings remain, and the independent reviewer records `Approved`. Product
decisions or specification changes block implementation. Only an approved
result may set implementation to `Verified` and be committed.

## Author Self-Review

### Pass 1 — Completeness and User Safety

Record findings and concrete revisions.

### Pass 2 — Independence and Verifiability

Record findings and concrete revisions.
