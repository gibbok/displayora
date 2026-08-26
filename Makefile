APP := Displayora
TARGET_TRIPLE := x86_64-apple-macosx13.0
ARCH ?= $(shell uname -m)
BUILD_DIR := build/$(ARCH)
APP_DIR := $(BUILD_DIR)/$(APP).app
ARTIFACT := build/$(APP)-$(ARCH).zip
SWIFT_SCRATCH := $(CURDIR)/.build/$(ARCH)
CLANG_MODULE_CACHE_PATH := $(SWIFT_SCRATCH)/clang-module-cache
SWIFTPM_MODULECACHE_OVERRIDE := $(SWIFT_SCRATCH)/swift-module-cache
SWIFT_BUILD_FLAGS := -c release --arch $(ARCH) --scratch-path "$(SWIFT_SCRATCH)" --disable-sandbox --manifest-cache local
DEVELOPER_PATH := $(shell xcode-select -p)
TEST_FRAMEWORKS := $(DEVELOPER_PATH)/Library/Developer/Frameworks

.PHONY: check-arch build package ci run rebuild test smoke-test clean stop

check-arch:
	@case "$(ARCH)" in arm64|x86_64) ;; *) echo "Unsupported ARCH: $(ARCH)" >&2; exit 2;; esac

build: check-arch
	CLANG_MODULE_CACHE_PATH="$(CLANG_MODULE_CACHE_PATH)" SWIFTPM_MODULECACHE_OVERRIDE="$(SWIFTPM_MODULECACHE_OVERRIDE)" swift build $(SWIFT_BUILD_FLAGS)
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp "$$(CLANG_MODULE_CACHE_PATH="$(CLANG_MODULE_CACHE_PATH)" SWIFTPM_MODULECACHE_OVERRIDE="$(SWIFTPM_MODULECACHE_OVERRIDE)" swift build $(SWIFT_BUILD_FLAGS) --show-bin-path)/$(APP)" "$(APP_DIR)/Contents/MacOS/$(APP)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	chmod +x "$(APP_DIR)/Contents/MacOS/$(APP)"
	plutil -lint "$(APP_DIR)/Contents/Info.plist"
	codesign --force --sign - --timestamp=none "$(APP_DIR)"
	codesign --verify --deep --strict "$(APP_DIR)"

package: build
	rm -f "$(ARTIFACT)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP_DIR)" "$(ARTIFACT)"
	unzip -tq "$(ARTIFACT)"
	@echo "Created $(ARTIFACT)"

ci: smoke-test package

run: stop build
	open "$(APP_DIR)"

rebuild: stop clean build
	open "$(APP_DIR)"

test:

	CLANG_MODULE_CACHE_PATH="$(CLANG_MODULE_CACHE_PATH)" SWIFTPM_MODULECACHE_OVERRIDE="$(SWIFTPM_MODULECACHE_OVERRIDE)" swift build --triple $(TARGET_TRIPLE)
	CLANG_MODULE_CACHE_PATH="$(CLANG_MODULE_CACHE_PATH)" SWIFTPM_MODULECACHE_OVERRIDE="$(SWIFTPM_MODULECACHE_OVERRIDE)" swift test --triple $(TARGET_TRIPLE) --enable-swift-testing --disable-xctest -Xswiftc -target -Xswiftc x86_64-apple-macosx14.0 -Xswiftc -F -Xswiftc $(TEST_FRAMEWORKS) -Xswiftc -Xlinker -Xswiftc -rpath -Xswiftc -Xlinker -Xswiftc $(TEST_FRAMEWORKS)

smoke-test: build
	sh Tests/smoke-test.sh "$(APP_DIR)" "$(ARCH)"

clean:

	rm -rf .build
	rm -rf build

stop:

	-pkill -x $(APP)
