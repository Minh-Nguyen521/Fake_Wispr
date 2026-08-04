APP_NAME  = FakeWispr
BUNDLE    = $(APP_NAME).app
BUILD_DIR = .build/release
CERT_NAME = FakeWispr Dev

.PHONY: build bundle run clean cert

cert:
	@if security find-certificate -c "$(CERT_NAME)" >/dev/null 2>&1; then \
		echo "✅ Certificate '$(CERT_NAME)' already exists"; \
	else \
		echo "Creating self-signed code signing certificate..."; \
		printf '[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=$(CERT_NAME)\n[ext]\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\nbasicConstraints=critical,CA:FALSE\n' > /tmp/fw-cert.cfg && \
		openssl req -x509 -newkey rsa:2048 -keyout /tmp/fw-key.pem -out /tmp/fw-cert.pem \
			-days 3650 -nodes -config /tmp/fw-cert.cfg 2>/dev/null && \
		openssl pkcs12 -export -legacy -out /tmp/fw.p12 \
			-inkey /tmp/fw-key.pem -in /tmp/fw-cert.pem -passout pass:fw 2>/dev/null && \
		security import /tmp/fw.p12 -k ~/Library/Keychains/login.keychain-db \
			-P "fw" -T /usr/bin/codesign && \
		security add-trusted-cert -r trustRoot \
			-k ~/Library/Keychains/login.keychain-db /tmp/fw-cert.pem && \
		rm -f /tmp/fw-key.pem /tmp/fw-cert.pem /tmp/fw.p12 /tmp/fw-cert.cfg && \
		echo "✅ Certificate '$(CERT_NAME)' created — run 'make run' now"; \
	fi

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
	codesign --force --sign "$(CERT_NAME)" --identifier "com.fakewispr.app" --entitlements FakeWispr.entitlements $(BUNDLE) 2>/dev/null || \
	codesign --force --sign - --identifier "com.fakewispr.app" --entitlements FakeWispr.entitlements $(BUNDLE)
	@echo "✅ $(BUNDLE) created"

run: bundle
	-pkill -x $(APP_NAME) 2>/dev/null; sleep 0.3
	-tccutil reset Accessibility com.fakewispr.app 2>/dev/null; sleep 0.3
	open $(BUNDLE)

clean:
	swift package clean
	rm -rf $(BUNDLE)
