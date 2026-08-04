APP_NAME  = FakeWispr
BUNDLE    = $(APP_NAME).app
BUILD_DIR = .build/release

.PHONY: build bundle run clean

build:
	swift build -c release 2>&1

bundle: build
	@echo "Creating app bundle..."
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	xattr -cr $(BUNDLE)
	codesign --force --sign - --identifier "com.fakewispr.app" --entitlements FakeWispr.entitlements $(BUNDLE)
	@echo "✅ $(BUNDLE) created"

run: bundle
	open $(BUNDLE)

clean:
	swift package clean
	rm -rf $(BUNDLE)
