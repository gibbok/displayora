# Displayora Specifications

This directory defines Displayora before implementation. Read
[ORIGINAL_PLAN.md](ORIGINAL_PLAN.md), this workflow, the relevant numbered
specification, and [CODE_REVIEW.md](CODE_REVIEW.md) before changing product
code.

## Authoring One Specification

1. The coordinator selects the lowest-numbered unblocked `Planned` row whose
   dependencies are `Ready` in `SPEC_STATUS.md`.
2. A fresh Codex author changes only that numbered specification and its
   tracker row, setting it to `Drafting` while working.
3. The author starts from [TEMPLATE.md](TEMPLATE.md), resolves every product and
   implementation choice, and records two self-review/revision passes.
4. The author sets the tracker row to `Ready`.
5. The coordinator runs `make check-specs` and `git diff --check`.
6. The coordinator commits that specification.
7. The coordinator pushes a dedicated `agent/spec-NN-<slug>` branch and opens
   a draft pull request using [PR_TEMPLATE.md](PR_TEMPLATE.md).
8. The coordinator confirms that the draft pull request diff contains only
   that specification and its tracker-row change, then hands it to a human
   reviewer before another specification author starts.

Use `docs(spec-NN): define <feature>` for numbered specification commits. The
workflow bootstrap uses `docs(specs): establish specification workflow`.

No numbered author edits another specification, workflow policy, validator, or
application code. A blocked dependency keeps downstream specifications
`Planned`.

### Human Review Pull Requests

Every numbered specification requires its own draft pull request. Workflow
policy changes made while producing the suite also use a dedicated draft pull
request. The description must begin with a short summary in everyday product
language: what a user or implementer gains from the specification and the
major behavior it locks down. Do not substitute a list of requirement IDs for
that summary.

The remainder names important decisions, why they matter, boundaries or risky
areas that deserve human attention, dependencies, and the exact checks run.
The PR remains a draft while handed to the human reviewer; only the human
review process decides when it is ready to merge.

If a predecessor is not merged, stack the new PR on the predecessor branch so
the Files changed view contains one numbered specification. State the stack
relationship in the description. After the predecessor merges, retarget or
rebase the next PR onto `main` before merging it. Human review and merge state
are GitHub concerns; `Ready` in `SPEC_STATUS.md` continues to mean the
specification itself passed repository validation.

## Implementing One Specification

1. Set its implementation to `In progress`.
2. One implementation agent implements only the specification and runs its
   focused checks.
3. A different review agent applies [CODE_REVIEW.md](CODE_REVIEW.md), reviews
   the entire working-tree diff, and creates the required durable report under
   `specs/reviews/`.
4. Codex repairs all in-scope findings, reruns focused and regression checks,
   and returns the updated diff to the independent reviewer.
5. Repeat until the report says `Final verdict: Approved` and all acceptance
   criteria pass.
6. Run `make check-review SPEC=NN`, mark implementation `Verified` and code
   review `Approved`, then commit.

If a finding requires a new product decision or a specification change, set
implementation to `Blocked` and stop. Never invent behavior merely to make a
review pass.

Implementation commits use `feat(spec-NN): implement <feature>`. Include the
implementation, repairs, final review report, and tracker update in the same
commit. Use `fix(spec-NN): address approved review findings` only for an
unavoidable post-commit correction.

## Deferring or Omitting an Optional Feature

Optional rows may be set to `Deferred` or `Omitted` without implementation.
The platform and release must still build with that module absent. Omission
means there are no controls, placeholders, shortcuts, settings, registrations,
imports, or failed checks associated with the feature.

## Validation

```sh
make check-specs
make check-architecture
make check-review SPEC=04
git diff --check
```

`check-review` is meaningful after implementation; it accepts a two-digit
specification ID. `make verify` is the full application validation command
defined by Specification 01.
