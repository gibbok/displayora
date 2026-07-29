SHELL := /bin/bash

DISPLAYORA_FEATURES ?=
export DISPLAYORA_FEATURES

SWIFT_FLAGS := -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
PACKAGE_FLAGS := --package-path app
# Keep native Swift Testing artifacts separate from builds made with older SDKs.
TEST_FLAGS := --scratch-path app/.build/native-sdk --disable-xctest

.PHONY: doctor check-specs check-architecture check-review build test format run bundle \
	install run-installed run-ui-harness test-install verify verify-feature clean

doctor:
	@python3 scripts/doctor.py

check-specs:
	@python3 scripts/check_specs.py

check-architecture:
	@python3 scripts/check_architecture.py

check-review:
	@python3 scripts/check_review.py "$(SPEC)"

build:
	swift build $(PACKAGE_FLAGS) $(SWIFT_FLAGS)

test:
	swift test $(PACKAGE_FLAGS) $(SWIFT_FLAGS) $(TEST_FLAGS)
	@python3 scripts/test_make_contract.py
	@python3 scripts/test_manifest_selection.py

format:
	swift format lint --recursive --strict app/Package.swift app/Sources app/Tests

run:
	swift run $(PACKAGE_FLAGS) $(SWIFT_FLAGS) Displayora

bundle:
	@scripts/build-app.sh

install: bundle
	@scripts/install-app.sh

run-installed:
	@open "$${DISPLAYORA_INSTALL_DESTINATION:-$${HOME}/Applications/Displayora.app}"

run-ui-harness:
	@scripts/run-foundation-ui-harness.sh "$(STATE)"

test-install: bundle
	@python3 scripts/test_transactions.py

verify: doctor check-specs format build test check-architecture bundle
	@python3 scripts/test_transactions.py

verify-feature:
	@python3 scripts/verify_feature.py "$(FEATURE)"

clean:
	@python3 scripts/clean.py
