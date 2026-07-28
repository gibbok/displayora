# Code Quality and Automatic Review Policy

This policy is mandatory for every numbered specification and implementation.
It cannot be weakened by a feature specification.

## Quality Standard

- Write idiomatic, straightforward Swift 6 with clear names and small, focused
  types and functions.
- Prefer value types. Introduce protocols only at meaningful system or testing
  boundaries; avoid premature abstraction and unnecessary generic layers.
- Keep SwiftUI declarative. Hardware access, persistence, scheduling, and
  business rules stay outside views and oversized view models.
- Isolate UI state with `@MainActor`. Values crossing actor or task boundaries
  must have safe `Sendable` semantics.
- Use explicit typed errors and recoverable failure paths. Do not use `try!`,
  unexplained force unwraps, silent error suppression, or crashes as control
  flow.
- Explain intent, recovery invariants, and API hazards in comments; do not
  restate readable code.
- Keep private macOS APIs in isolated adapters with runtime and availability
  checks.
- Optional modules depend on platform contracts, never sibling feature
  modules.
- Require warning-free builds, formatting, focused tests, the full regression
  suite, architecture checks, and strict concurrency validation.

Working code is not sufficient. A reviewer must request changes for code that
is needlessly difficult to read, non-idiomatic, tightly coupled,
insufficiently tested, inaccessible, or unsafe during display recovery.

## Independent Review and Automatic Repair

Before any implementation commit:

1. A reviewer different from the implementation author reads the numbered
   specification and acceptance criteria.
2. The reviewer examines the complete working-tree diff, new and changed
   tests, relevant shared interfaces, and captured build, test, format,
   architecture, and strict-concurrency results.
3. The reviewer creates `specs/reviews/NN-<feature>-review.md` using
   [reviews/TEMPLATE.md](reviews/TEMPLATE.md). Each round lists blocking and
   non-blocking findings, affected requirement IDs and files, required
   corrections, and validation commands/results.
4. Codex automatically fixes all in-scope blocking findings. It also fixes
   non-blocking findings that improve readability, idiomatic Swift, safety,
   accessibility, or maintainability without expanding feature scope.
5. Codex must not weaken tests or acceptance criteria, delete coverage,
   suppress warnings, hide failures, or broaden exclusions to gain approval.
6. Codex reruns the specification’s focused checks and the full regression
   checks.
7. The same independent reviewer reviews the corrected complete diff and adds
   another round to the report.
8. Review and repair repeat until no blocking findings remain, every acceptance
   criterion passes, final validation results are recorded, and the reviewer
   writes `Final verdict: Approved`.

If a correction requires an unresolved product decision or specification
change, the reviewer records it and Codex marks implementation `Blocked`.

Only after approval may the tracker say implementation `Verified` and code
review `Approved`, and only then may the coordinator commit.

## Required Review Evidence

Every approved report records:

- Specification ID and feature name.
- Implementation author and independent reviewer identifiers.
- Every review round and its disposition.
- Requirement IDs and files affected by each finding.
- Automatic fixes performed.
- Exact focused and full-regression commands with pass/fail results.
- Confirmation that tests and acceptance criteria were not weakened.
- Confirmation that optional-feature omission and sibling independence still
  pass.
- The literal line `Blocking findings remaining: 0`.
- The literal line `Final verdict: Approved`.
