SHELL := /bin/zsh
APP_DIR := app
SWIFT_FLAGS := -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete

.PHONY: doctor check-specs check-architecture check-review build test format run bundle verify verify-feature clean

doctor:
	@command -v swift >/dev/null
	@command -v python3 >/dev/null
	@command -v lipo >/dev/null
	@command -v codesign >/dev/null
	@echo "Displayora development tools are available."

check-specs:
	@python3 scripts/check_specs.py

check-architecture:
	@python3 scripts/check_architecture.py

check-review:
	@test -n "$(SPEC)" || { echo "usage: make check-review SPEC=NN" >&2; exit 2; }
	@python3 scripts/check_review.py "$(SPEC)"

build:
	@test -f "$(APP_DIR)/Package.swift" || { echo "app/Package.swift has not been implemented" >&2; exit 1; }
	swift build --package-path "$(APP_DIR)" $(SWIFT_FLAGS)

test:
	@test -f "$(APP_DIR)/Package.swift" || { echo "app/Package.swift has not been implemented" >&2; exit 1; }
	swift test --package-path "$(APP_DIR)" $(SWIFT_FLAGS)

format:
	@test -f "$(APP_DIR)/Package.swift" || { echo "app/Package.swift has not been implemented" >&2; exit 1; }
	swift format lint --recursive --strict "$(APP_DIR)/Package.swift" "$(APP_DIR)/Sources" "$(APP_DIR)/Tests"

run:
	@test -f "$(APP_DIR)/Package.swift" || { echo "app/Package.swift has not been implemented" >&2; exit 1; }
	swift run --package-path "$(APP_DIR)" Displayora

bundle:
	@test -x scripts/build-app.sh || { echo "scripts/build-app.sh has not been implemented" >&2; exit 1; }
	scripts/build-app.sh

verify: doctor check-specs format build test check-architecture

verify-feature:
	@FEATURE="$(FEATURE)" python3 scripts/verify_feature.py

clean:
	@if test -f "$(APP_DIR)/Package.swift"; then swift package --package-path "$(APP_DIR)" clean; fi
