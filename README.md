# Displayora

**Your displays, made simple.**

Displayora is specified as a modular macOS 13+ menu-bar application for Intel
and Apple Silicon. The implementation is intentionally preceded by a
standalone, incrementally committed specification suite.

- [Original approved plan](specs/ORIGINAL_PLAN.md)
- [Specification status](specs/SPEC_STATUS.md)
- [Specification workflow](specs/README.md)

## Local foundation build

Specification 01 is implemented on the `spec-01` branch as a local-only Swift
6 application. It has no external package dependencies, networking, telemetry,
remote configuration, updater, launch-at-login behavior, or release
publication path.

From a terminal with a compatible Swift 6 toolchain and macOS SDK:

```sh
DISPLAYORA_FEATURES='' make verify
DISPLAYORA_FEATURES='' make install
make run-installed
```

`make install` creates or safely replaces
`~/Applications/Displayora.app`. It validates the universal `arm64`/`x86_64`
binary, locked Info.plist, system load paths, executable permissions, and
ad-hoc signature before committing the replacement. A failed replacement
restores the prior installation. `make clean` removes only `app/.build` and
`dist`; it never removes the installed application.

Foundation intentionally has no optional display features. Non-empty
`DISPLAYORA_FEATURES` selections fail until their owning specifications are
implemented. For accessibility review of generic foundation states, use the
compile-time-only harness:

```sh
make run-ui-harness STATE=loading
make run-ui-harness STATE=populated
make run-ui-harness STATE=failed
```

The harness is forced off by universal bundle and installation workflows and
is rejected if its fixture marker appears in a production bundle.

## Make commands

- `make doctor` — check the required development tools and environment.
- `make build` — compile the application.
- `make test` — run all automated tests.
- `make run` — build and launch the app directly.
- `make bundle` — create the macOS application bundle.
- `make install` — bundle and install the app into `~/Applications`.
- `make run-installed` — launch the installed app.
- `make clean` — remove generated build files.
- `make format` — check Swift code formatting.
- `make verify` — run the complete validation suite.
- `make check-specs` — validate project specification files.
- `make check-architecture` — check architectural rules.
- `make check-review SPEC=NN` — validate a specific review document.
- `make run-ui-harness STATE=loading|populated|failed` — launch the UI harness.
- `make test-install` — test bundle and installation transactions.
- `make verify-feature FEATURE=NAME` — verify a specific feature.

## Recommended implementation order

Implement the feature specifications in this order:

1. Brightness
2. Contrast
3. Night Comfort
4. Resolution Selector
5. Volume and Mute
6. Keyboard Controls
7. Disable and Re-enable Display

Each feature should be implemented in its own draft pull request. Keyboard
Controls and Disable and Re-enable Display require additional platform review;
Disable and Re-enable Display is the highest-risk feature because it relies on
private display APIs and recovery behavior.
