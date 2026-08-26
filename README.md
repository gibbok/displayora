# Displayora

> Your displays, exactly how you like them—one click away.

Displayora is a lightweight macOS menu bar app that puts your whole display
setup within reach. Dim a bright external monitor, bring a screen back online,
add a warm evening tint, or restore your preferred workspace without digging
through System Settings.

## Make every desk setup effortless

- **Control every display from the menu bar.** Enable or disable individual
  screens and see their status at a glance.
- **Tune each screen independently.** Adjust brightness per display and switch
  on a warm Night mode when it is time to wind down.
- **Save the way you work.** Capture your active displays, brightness levels,
  and Night mode as a named setup; apply it again whenever you return to that
  workspace.
- **Stay in control when your desk changes.** Update, rename, or remove saved
  setups, and see when a saved setup cannot match the displays currently
  connected.
- **Reset with confidence.** Restore every display, full brightness, and the
  standard color mode in one action.

Whether you are moving between focus time, a presentation, and a late-night
session, Displayora keeps your displays in sync with the moment.

## Download

Download [the latest release](https://github.com/gibbok/displayora/releases/latest):

- **Displayora-Intel.zip** for Intel-based Macs running macOS 13 or later.

Open Displayora and its display icon will appear in your menu bar—ready when
you need it and out of the way when you do not.

## Development

```sh
make run
make test
```

`make build` creates a signed Intel app bundle at
`build/x86_64/Displayora.app`. Use `make smoke-test` to build and verify the
bundle, or `make package` to create `build/Displayora-Intel.zip`.

GitHub Actions builds, tests, and smoke-tests the Intel (`x86_64`) bundle on an
Intel runner. Pushing a version tag such as `v0.1.0` automatically creates a
GitHub Release containing the Intel download. Pull-request and main-branch
builds are also available as workflow artifacts for 14 days.
