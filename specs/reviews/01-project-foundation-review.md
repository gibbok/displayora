# 01 — Project Foundation Implementation Review

- Specification: `01`
- Implementation author: `/root`
- Independent reviewer: `/root/spec01_review`
- Review status: `Changes requested`

## Round 1

### Evidence examined

- Specification and acceptance criteria: `specs/01-project-foundation.md`
- Complete working-tree diff and all new Swift, shell, Python, plist, and Make files
- Five focused XCTest targets and shared interfaces
- Strict production build, universal bundle, installation, and partial Intel evidence

### Blocking findings

The reviewer found eleven source or evidence issues:

1. Shell interpolation allowed a malformed feature selection to alter the
   `bundle` recipe (`DORA-01-008`, `DORA-01-011`).
2. Rollback tests modified the signed prior app and did not enter the
   `build-app.sh` failure path (`DORA-01-015`).
3. Installed plist validation omitted required locked values (`DORA-01-004`).
4. Feature-host usage, selection, count, mismatch, and registration exits
   lacked focused coverage (`DORA-01-010`, `DORA-01-013`).
5. Contribution factories and command actions did not express `@MainActor` in
   their closure types (`DORA-01-005`).
6. The application model contained an unexpected-error crash path
   (`DORA-01-007`).
7. Feature identity mismatch was misreported as a control ownership error
   (`DORA-01-006`).
8. Architecture checks did not inspect evaluated SwiftPM dependency edges
   (`DORA-01-002`).
9. Make contract checks asserted names rather than fixed behavior
   (`DORA-01-011`).
10. The bundle validator accepted a non-executable application
    (`DORA-01-015`).
11. Loading, populated, failure, and retry UI states had no launchable manual
    review route (`DORA-01-017`).

Native Apple Silicon, complete Intel UI, accessibility, and full automated
evidence were also absent (`DORA-01-012`, `DORA-01-016`–`018`).

### Non-blocking findings

- Restrict production installation to the resolved user Applications folder.
- Use collision-safe transaction staging.
- Assert that the signature is specifically ad-hoc.
- Keep test-only UI fixture labels out of production binaries.

### Automatic repairs and validation

The implementation:

- removed Make interpolation and added a hostile-input dry-run regression;
- tests byte-identical valid rollback through `build-app.sh` and the installer;
- validates every locked plist value, executable permissions, architectures,
  load paths, ad-hoc signature, and test-fixture absence;
- extracted deterministic host execution logic and covered all specified exit
  categories;
- annotated factories/actions `@MainActor`;
- made registry errors typed and removed the application crash catch;
- added `featureIdentityMismatch` and atomic rollback coverage;
- validates the evaluated `swift package dump-package` graph;
- checks exact Make prerequisites, actions, and invalid arguments; and
- added a compile-time-only loading/populated/fail-then-retry UI harness.

Validation after repair:

```text
swift format lint --recursive --strict app/Package.swift app/Sources app/Tests
PASS

SDKROOT=... DISPLAYORA_FEATURES='' swift build --package-path app \
  --scratch-path app/.build/sdk15 \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
PASS

SDKROOT=... DISPLAYORA_FEATURES='' python3 scripts/check_architecture.py
PASS

SDKROOT=... python3 scripts/test_manifest_selection.py
PASS

python3 scripts/test_make_contract.py
PASS

SDKROOT=... DISPLAYORA_FEATURES='' make bundle
PASS — x86_64 arm64, ad-hoc signature

SDKROOT=... DISPLAYORA_FEATURES='' python3 scripts/test_transactions.py
PASS — bundle and installer success/rollback

git diff --check
PASS
```

Tests and acceptance criteria were not weakened.

## Round 2

### Evidence examined

- The corrected complete tree and all Round 1 dispositions
- Strict normal and compile-time UI-harness production builds
- Evaluated package graph, Make behavior, manifest selection, bundle,
  installer, and installed Intel process evidence

### Blocking findings

One source isolation issue remained initially: release commands inherited
`DISPLAYORA_FOUNDATION_UI_HARNESS`. All four release invocations now force the
harness off, the validator rejects its fixture marker, and the transaction
test deliberately exports the hostile value while validating production
output. The reviewer found no remaining in-scope source blocker.

Two acceptance-evidence blockers remain:

1. `make test` and full `make verify` cannot run because this host's Command
   Line Tools installation pairs a Swift 6.2.4 compiler with a Swift 6.2.3 SDK
   and contains no `XCTest.swiftmodule`. The compatible older SDK builds
   production and the harness but also lacks XCTest.
2. No user-provided native Apple Silicon host or complete manual Intel/Apple
   Silicon accessibility matrix is available. Menu-bar, Settings, Dock, Quit,
   VoiceOver, keyboard, display-options, retry-focus, and permission-prompt
   evidence therefore remains incomplete.

### Automatic repairs and validation

Round 2 source and automation checks passed. Current Intel evidence:

```text
Hardware/process architecture: x86_64
macOS: 15.7.7 (24G720)
Installed process: running from ~/Applications/Displayora.app
Bundle architectures: x86_64 arm64
Installed/dist executable SHA-256:
a44f7484fbad7c603968440aa9ba0897ba6f96c330f9a54602cb502ffa062594
Signature: ad-hoc, valid
Production fixture marker: absent
```

### Coordinator evidence status update — 2026-07-29

- Native Intel Swift Testing evidence: **Passed** — `make test` completed with
  21 tests in 5 suites, plus Make contract and manifest-selection checks.
- Apple Silicon runtime and accessibility evidence: **Pending**.
- Reason: no Apple Silicon host is currently available.
- The universal `arm64` bundle slice is validated, but it does not replace a
  native runtime test.
- The pending evidence remains a completion blocker; no acceptance criterion
  is waived or weakened.

## Final Approval

- Acceptance criteria passing: Source and local bundle criteria pass; full
  automated and two-host manual evidence remains blocked.
- Focused checks: Production checks pass; XCTest blocked by local toolchain.
- Full regression checks: Blocked by local XCTest/toolchain installation.
- Standalone and omission checks: Manifest, composition, host empty failure,
  release harness exclusion, and binary marker checks pass.
- Tests or acceptance criteria weakened: No
- Blocking findings remaining: 2
- Final verdict: Changes requested
