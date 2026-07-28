# Displayora

**Your displays, made simple.**

Displayora is specified as a modular macOS 13+ menu-bar application for Intel
and Apple Silicon. The implementation is intentionally preceded by a
standalone, incrementally committed specification suite.

- [Original approved plan](specs/ORIGINAL_PLAN.md)
- [Specification status](specs/SPEC_STATUS.md)
- [Specification workflow](specs/README.md)

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
