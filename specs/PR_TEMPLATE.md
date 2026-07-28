# Draft Specification Pull Request Description

Use this body for every numbered specification draft pull request. Replace
the guidance text and remove this introductory sentence.

## Summary

In two or three sentences, explain in everyday language what this
specification enables and what experience or safety guarantee it establishes.
A reviewer should understand the outcome without reading requirement IDs.

## What this specification decides

- Name the most important product behavior.
- Name the important architecture or module boundary.
- Name the failure, recovery, accessibility, or platform guarantee that is
  easiest to overlook.

## Why it matters

Explain the user or developer impact and why these decisions need to be fixed
before implementation.

## Human review focus

- Call out the highest-risk or most subjective decision.
- Identify any private API, permission, destructive display operation,
  recovery path, or hardware-specific behavior that deserves scrutiny.
- Say explicitly when none of those risks apply.

## Dependencies and stack

State the specification dependencies. If the PR is stacked, name the
predecessor branch/PR and state that this PR will be retargeted or rebased onto
`main` after the predecessor merges.

## Validation

```text
make check-specs
git diff --check
```

Record the actual result of each command and confirm that the PR diff contains
only the numbered specification and its tracker-row update.
