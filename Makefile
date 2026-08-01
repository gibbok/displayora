APP := Displayora
TARGET_TRIPLE := x86_64-apple-macosx13.0
CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/clang-module-cache
SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/swift-module-cache
DEVELOPER_PATH := $(shell xcode-select -p)
TEST_FRAMEWORKS := $(DEVELOPER_PATH)/Library/Developer/Frameworks

.PHONY: run test clean stop

run: stop clean

	CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) SWIFTPM_MODULECACHE_OVERRIDE=$(SWIFTPM_MODULECACHE_OVERRIDE) swift run --triple $(TARGET_TRIPLE) $(APP)

test:

	CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) SWIFTPM_MODULECACHE_OVERRIDE=$(SWIFTPM_MODULECACHE_OVERRIDE) swift build --triple $(TARGET_TRIPLE)
	CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) SWIFTPM_MODULECACHE_OVERRIDE=$(SWIFTPM_MODULECACHE_OVERRIDE) swift test --triple $(TARGET_TRIPLE) --enable-swift-testing --disable-xctest -Xswiftc -target -Xswiftc x86_64-apple-macosx14.0 -Xswiftc -F -Xswiftc $(TEST_FRAMEWORKS) -Xswiftc -Xlinker -Xswiftc -rpath -Xswiftc -Xlinker -Xswiftc $(TEST_FRAMEWORKS)

clean:

	rm -rf .build

stop:

	-pkill -x $(APP)
