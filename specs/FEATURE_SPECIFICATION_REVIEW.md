# Repository-Wide Specification Review

## Scope

This review covers every Markdown document under `specs/`, including
Specifications 01–11, the workflow and review policies, the status tracker,
templates, and implementation-review guidance. Application implementation,
scripts, and other non-Markdown files are intentionally out of scope.

| IDs | Area | Specification status | Implementation status |
|---|---|---|---|
| 01–03 | Required platform | Ready | Not started |
| 04–10 | Optional standalone features | Ready | Not started |
| 11 | Required direct release | Ready | Not started |

## Review Method

The review used two passes:

1. Structural and traceability review: metadata, dependencies, stable
   requirement IDs, acceptance-criterion coverage, relative Markdown links,
   unresolved placeholders, canonical feature slugs, and tracker consistency.
2. Implementation-readiness review: module boundaries, stable persisted IDs,
   value normalization, failure and recovery semantics, permission behavior,
   command routing, hardware-specific assumptions, and exact release inputs
   and outputs.

Every numbered specification retains the required sections, documented
self-review passes, and a requirement-to-acceptance mapping.

## Findings and Resolutions

| Area | Finding | Resolution |
|---|---|---|
| Status tracker | The tracker linked to `specs/README.md` as though it were outside the `specs` directory. | Corrected the relative link to `README.md`. |
| Specification 11 | Its metadata said `Ready`, while the authoritative tracker said `Planned`. | Marked Specification 11 `Ready` in the tracker. |
| Feature identity | Optional modules had canonical selection slugs but did not explicitly lock their static `FeatureID` values. | Made every feature ID exactly equal to its canonical selection slug and documented that invariant in Specification 01. |
| Keyboard commands | Several feature specifications mentioned commands without defining stable IDs or multi-display behavior. | Defined the Brightness, Contrast, Volume/Mute, and safe re-enable commands, including all-eligible-display semantics; explicitly omitted unsafe or ambiguous v1 commands for Resolution and Night Comfort. |
| DDC continuous values | Brightness, Contrast, and Volume used user-facing percentages without defining conversion from a monitor's device-specific maximum. | Defined nonzero-range validation, raw-to-percent and percent-to-raw conversion, no-op probe verification, and one-percentage-point normalized read-back tolerance. |
| DDC mute | “Supported mute control” left the VCP code and values to implementation guesswork. | Locked mute to VCP `0x8D`, values `0x01` and `0x02`, and rejected unknown or complex vendor semantics. |
| Shortcut conflicts | A hard-coded notion of every reserved system shortcut is neither complete nor durable. | Locked the adapter to public Carbon hot-key registration, preserved the prior binding until replacement succeeds, and made operating-system registration failure authoritative. |
| Registry replacement | Runtime wording implied mutable command registration, while Specification 01 exposes immutable snapshots. | Defined atomic command-snapshot replacement only when the registry itself is replaced after retry. |
| Night Comfort | The state diagram could enter `Suspended` from Manual but could recover only to scheduled-active state. | Added recovery to Manual, scheduled-active, scheduled-inactive, and Off according to current intent. |
| Direct release | The release specification did not provide an exact automation entry point or deterministic publication paths. | Added a validated non-interactive `make release` contract and fixed DMG and manifest output paths. |

## Cross-Specification Decisions

- Optional modules depend only on Specifications 01–03 and Apple frameworks;
  no optional feature imports or discovers a sibling.
- Canonical feature slugs and static feature IDs are the same value.
- Commands that affect displays use explicit stable IDs. In v1, Brightness,
  Contrast, and Volume/Mute act on all currently active eligible displays.
- Resolution changes remain UI-only because a shortcut cannot safely choose a
  display and mode or bypass confirmation.
- Display disable remains confirmation-only; only re-enable-all is routable as
  a global safety command.
- Night Comfort mode changes remain Settings-only in v1 because a toggle would
  be ambiguous among Off, Manual, and Schedule.
- DDC support requires verified read/write behavior, not a capability claim or
  successful write alone.
- The private display-enable path in Specification 09 remains the highest-risk
  area. Runtime rejection, final-display protection, timed recovery,
  transactional fallback, and native Intel/Apple Silicon evidence are
  mandatory; implementation must block rather than weaken those gates.
- Specification 11 extends the Makefile only when release implementation
  begins. Secrets remain in Keychain and are never command arguments, files,
  logs, or repository content.

## Implementation Handoff

Implement in the dependency and risk order documented by the root README.
Each numbered implementation remains isolated in its own draft pull request
and must include focused tests, regression evidence, the durable independent
review report, and its tracker update. A missing platform capability or a
finding that requires a new product decision sets the implementation to
`Blocked`; Codex must not invent behavior to make a check pass.

## Review Result

The specification suite is internally consistent and sufficiently explicit
for staged Codex implementation. All numbered specifications are `Ready`;
all implementations remain `Not started`. This review changes documentation
only and does not create application code or development tooling.
