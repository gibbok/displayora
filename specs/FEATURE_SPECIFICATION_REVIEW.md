# Specification Suite Review

## Scope

This review covers the complete Displayora specification suite and its
Markdown workflow documents. Application implementation and repository tooling
are intentionally out of scope.

| ID | Specification | Specification status | Implementation status |
|---|---|---|---|
| 01 | Project Foundation | Ready | Not started |
| 02 | Menu-Bar Shell and Onboarding | Ready | Not started |
| 03 | Display Platform and Capabilities | Ready | Not started |
| 04 | Brightness | Ready | Not started |
| 05 | Contrast | Ready | Not started |
| 06 | Volume and Mute | Ready | Not started |
| 07 | Resolution Selector | Ready | Not started |
| 08 | Keyboard Controls | Ready | Not started |
| 09 | Disable and Re-enable Display | Ready | Not started |
| 10 | Night Comfort | Ready | Not started |
| 11 | Direct Distribution and Release | Ready | Not started |

## Review method

The review checked:

1. Metadata and dependency consistency against
   [ORIGINAL_PLAN.md](ORIGINAL_PLAN.md) and
   [SPEC_STATUS.md](SPEC_STATUS.md).
2. Required sections, stable requirement IDs, acceptance criteria, test/manual
   identifiers, omission behavior, accessibility, permissions, failure and
   recovery, and native Intel/Apple Silicon coverage.
3. Cross-specification interfaces, canonical feature slugs, verification
   commands, state transitions, lifecycle ownership, and restoration
   invariants.
4. Relative Markdown links and unresolved placeholders.
5. Release terminology against Apple's
   [custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

The repository remains in its specification-only phase. The Makefile and
validation-script paths named by Specification 01 are implementation contracts,
not current review tools. This review therefore used Markdown inspection and
does not add or modify tooling.

## Findings and resolutions

| Area | Finding | Resolution |
|---|---|---|
| Tracker | Specification 11 declared itself `Ready` while the authoritative tracker said `Planned`. | The tracker now marks all eleven completed specifications `Ready`. |
| Workflow link | The tracker linked to `specs/specs/README.md` when resolved from inside the `specs` directory. | The link now resolves to the local [README.md](README.md). |
| Specification-only validation | The authoring workflow required `make check-specs` before Specification 01 has implemented that command. | The workflow now defines manual Markdown checks before implementation and adds `make check-specs` after Specification 01 creates it. |
| Verification scope | Specification 01 said every `verify-feature` value maps to one optional module and must run the one-feature host, but Specifications 01–03 and 11 use platform/release scopes. | The verifier contract now distinguishes `foundation`, `shell`, `display-platform`, and `release` scopes from the seven optional-feature scopes. Only optional-feature scopes invoke the host with one installed feature. |
| Common handoff | Specifications 01–03 omitted the Pull Request Handoff section present in the template and Specifications 04–11. | All numbered specifications now use the same handoff structure. |
| Display disable safety | A private-adapter error could fall through to mirror-plus-gamma fallback without proving that the private call left topology unchanged. | Fallback now requires a fresh unchanged-topology confirmation; uncertain or partial private state enters recovery, blocks further disable actions, and retains an idempotent recovery path. |
| Night Comfort state | One generic suspended state always returned to scheduled-active behavior, even when suspension began in Manual mode or the schedule ended while suspended. | Manual and scheduled suspension are distinct, mode changes are explicit, and schedule/time/safety are reevaluated before reapplication. Pause and apply-failure messages now report their actual cause. |
| Release notarization | The release specification described the app inside a submitted DMG as stapled and did not clearly identify the outer distribution container. | The app is signed with Hardened Runtime; the outer DMG is submitted, accepted, stapled, validated, and tested offline. Adjacent manifests record the exact clean commit and artifact evidence. |
| Authoring template | The template allowed timing, bounds, persistence, adapter, and verification choices to remain implicit. | The template now requires implementation-relevant choices and concrete automated/manual evidence to be resolved before a specification is `Ready`. |

## Existing feature decisions retained

The review retained the established safety and independence decisions for
Brightness, Contrast, Volume and Mute, Resolution Selector, Keyboard Controls,
Disable and Re-enable Display, and Night Comfort. In particular:

- hardware control remains preferred over explicitly safe software fallback;
- optional features depend only on Specifications 01–03, not sibling modules;
- display identity, endpoint generations, retries, rollback, restoration, HDR,
  sleep/wake, hot-plug, and omission behavior remain explicit;
- accessibility and permission behavior remain part of each acceptance
  contract; and
- implementation still requires independent Codex review and automatic repair
  before `Verified`.

## Review result

All eleven specifications are internally consistent at the Markdown contract
level and are ready to guide sequential Codex implementation. Hardware,
private-API, signing, notarization, Gatekeeper, and native-architecture claims
still require the manual evidence required by their specifications; a future
implementation must not replace those checks with simulated results.
