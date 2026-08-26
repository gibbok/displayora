# Displayora

Displayora is a lightweight macOS menu bar app for managing connected displays.

## Download

Open the [latest release](https://github.com/gibbok/displayora/releases/latest) and download:

- **Displayora-Apple-Silicon.zip** for Macs with an Apple M-series processor.
- **Displayora-Intel.zip** for Intel-based Macs.

It can:

- Enable or disable displays.
- Adjust brightness and Night mode.
- Save, apply, rename, and delete display setups.
- Reset all displays, brightness, and Night mode.

Requires macOS 13 or later.

## Development

```sh
make run
make test
```

`make build` creates a signed app bundle for the current architecture at
`build/<architecture>/Displayora.app`. Use `make smoke-test` to build and verify
the bundle, or `make package` to create `build/Displayora-<architecture>.zip`.

GitHub Actions builds and smoke-tests native `arm64` and `x86_64` bundles on
Apple Silicon and Intel runners. Pushing a version tag such as `v0.1.0`
automatically creates a GitHub Release containing both downloads. Pull-request
and main-branch builds are also available as workflow artifacts for 14 days.
