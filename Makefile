SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := help

APP := $(CURDIR)/build/GazeVeil.app
DIST_DIR := $(CURDIR)/build/dist
VERSION ?= $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' App/Info.plist)
BUILD_NUMBER ?= $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' App/Info.plist)
ARCH ?= $(shell uname -m)
NAME := GazeVeil-$(VERSION)-macOS-$(ARCH)
UPLOAD_ARCHIVE := $(DIST_DIR)/$(NAME)-notarization.zip
FINAL_ARCHIVE := $(DIST_DIR)/$(NAME).zip
NOTARY_RESULT := $(DIST_DIR)/$(NAME)-notary-result.json
NOTARY_LOG := $(DIST_DIR)/$(NAME)-notary-log.json
DMG := $(DIST_DIR)/$(NAME).dmg
DMG_STAGING := $(DIST_DIR)/$(NAME)-dmg
DMG_NOTARY_RESULT := $(DIST_DIR)/$(NAME)-dmg-notary-result.json
DMG_NOTARY_LOG := $(DIST_DIR)/$(NAME)-dmg-notary-log.json

TEAM_ID ?= 8JL39GK2DC
SIGNING_IDENTITY ?= Developer ID Application: Kartik Labhshetwar ($(TEAM_ID))
NOTARY_PROFILE ?= GazeVeilNotary

.PHONY: help version set-version check-version test local run credentials check-credentials release release-all check-certificate sign notarize verify dmg clean-dist

help:
	@echo 'Local:'
	@echo '  make version                      Show bundle version and build number'
	@echo '  make set-version VERSION=0.1.1 BUILD_NUMBER=2'
	@echo '  make test                         Run the test suite'
	@echo '  make local                        Build an ad-hoc-signed local app'
	@echo '  make run                          Build and open the local app'
	@echo ''
	@echo 'First release setup:'
	@echo '  make credentials APPLE_ID=you@example.com'
	@echo ''
	@echo 'Direct distribution:'
	@echo '  make release                      Release $(VERSION) ($(BUILD_NUMBER))'
	@echo '  make release-all                  Release Apple Silicon and Intel builds'
	@echo '  make release VERSION=0.1.1 BUILD_NUMBER=2'
	@echo '  Output: build/dist/$(NAME).dmg and .zip'
	@echo ''
	@echo 'This does not upload anything to GitHub.'

version:
	@echo 'GazeVeil $(VERSION) ($(BUILD_NUMBER))'

set-version: check-version
	/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' App/Info.plist
	/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion $(BUILD_NUMBER)' App/Info.plist
	@echo 'Set GazeVeil to $(VERSION) ($(BUILD_NUMBER))'

check-version:
	@if [[ ! "$(VERSION)" =~ '^[0-9]+\.[0-9]+\.[0-9]+$$' ]]; then \
		echo 'VERSION must use SemVer, for example 0.1.0'; \
		exit 2; \
	fi
	@if [[ ! "$(BUILD_NUMBER)" =~ '^[1-9][0-9]*$$' ]]; then \
		echo 'BUILD_NUMBER must be a positive integer'; \
		exit 2; \
	fi

test:
	swift test

local: check-version
	VERSION="$(VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" ARCH="$(ARCH)" ./build.sh

run: check-version
	VERSION="$(VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" ARCH="$(ARCH)" ./build.sh --run

credentials:
	@if [[ -z "$(APPLE_ID)" ]]; then \
		echo 'Usage: make credentials APPLE_ID=you@example.com'; \
		exit 2; \
	fi
	xcrun notarytool store-credentials "$(NOTARY_PROFILE)" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--validate
	@echo 'Saved and validated Keychain profile: $(NOTARY_PROFILE)'

check-credentials:
	@xcrun notarytool history --keychain-profile "$(NOTARY_PROFILE)" >/dev/null 2>&1 || { \
		echo 'Missing or invalid notarization profile: $(NOTARY_PROFILE)'; \
		echo 'Run: make credentials APPLE_ID=you@example.com'; \
		exit 1; \
	}

check-certificate:
	@security find-identity -v -p codesigning | \
		/usr/bin/grep -Fq '"$(SIGNING_IDENTITY)"' || { \
			echo 'Missing signing identity: $(SIGNING_IDENTITY)'; \
			exit 1; \
		}

sign: check-version check-certificate
	VERSION="$(VERSION)" BUILD_NUMBER="$(BUILD_NUMBER)" ARCH="$(ARCH)" ./build.sh
	codesign --force --timestamp --options runtime \
		--sign "$(SIGNING_IDENTITY)" "$(APP)"
	codesign --verify --strict --verbose=2 "$(APP)"

notarize: check-credentials
	mkdir -p "$(DIST_DIR)"
	rm -f "$(UPLOAD_ARCHIVE)" "$(NOTARY_RESULT)" "$(NOTARY_LOG)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(UPLOAD_ARCHIVE)"
	xcrun notarytool submit "$(UPLOAD_ARCHIVE)" \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait --output-format json | tee "$(NOTARY_RESULT)"
	@[[ -s "$(NOTARY_RESULT)" ]] || { \
		echo 'Notary service returned no result'; \
		exit 1; \
	}
	@submission_id=$$(plutil -extract id raw -o - "$(NOTARY_RESULT)"); \
	notary_status=$$(plutil -extract status raw -o - "$(NOTARY_RESULT)"); \
	xcrun notarytool log "$$submission_id" "$(NOTARY_LOG)" \
		--keychain-profile "$(NOTARY_PROFILE)"; \
	if [[ "$$notary_status" != 'Accepted' ]]; then \
		echo "Notarization failed: $$notary_status (see $(NOTARY_LOG))"; \
		exit 1; \
	fi
	xcrun stapler staple "$(APP)"

verify:
	codesign --verify --strict --verbose=2 "$(APP)"
	xcrun stapler validate "$(APP)"
	spctl --assess --type execute --verbose=4 "$(APP)"
	mkdir -p "$(DIST_DIR)"
	rm -f "$(FINAL_ARCHIVE)" "$(FINAL_ARCHIVE).sha256"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(FINAL_ARCHIVE)"
	cd "$(DIST_DIR)" && shasum -a 256 "$(notdir $(FINAL_ARCHIVE))" > "$(notdir $(FINAL_ARCHIVE)).sha256"
	@echo 'Ready to publish: $(FINAL_ARCHIVE)'

dmg: check-credentials check-certificate
	rm -rf "$(DMG_STAGING)"
	rm -f "$(DMG)" "$(DMG).sha256" "$(DMG_NOTARY_RESULT)" "$(DMG_NOTARY_LOG)"
	mkdir -p "$(DMG_STAGING)"
	ditto "$(APP)" "$(DMG_STAGING)/GazeVeil.app"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "GazeVeil $(VERSION)" -srcfolder "$(DMG_STAGING)" \
		-ov -format UDZO "$(DMG)"
	codesign --force --timestamp --sign "$(SIGNING_IDENTITY)" "$(DMG)"
	codesign --verify --verbose=2 "$(DMG)"
	xcrun notarytool submit "$(DMG)" \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait --output-format json | tee "$(DMG_NOTARY_RESULT)"
	@[[ -s "$(DMG_NOTARY_RESULT)" ]] || { \
		echo 'Notary service returned no DMG result'; \
		exit 1; \
	}
	@submission_id=$$(plutil -extract id raw -o - "$(DMG_NOTARY_RESULT)"); \
	dmg_notary_status=$$(plutil -extract status raw -o - "$(DMG_NOTARY_RESULT)"); \
	xcrun notarytool log "$$submission_id" "$(DMG_NOTARY_LOG)" \
		--keychain-profile "$(NOTARY_PROFILE)"; \
	if [[ "$$dmg_notary_status" != 'Accepted' ]]; then \
		echo "DMG notarization failed: $$dmg_notary_status (see $(DMG_NOTARY_LOG))"; \
		exit 1; \
	fi
	xcrun stapler staple "$(DMG)"
	xcrun stapler validate "$(DMG)"
	spctl --assess --type open --context context:primary-signature --verbose=4 "$(DMG)"
	cd "$(DIST_DIR)" && shasum -a 256 "$(notdir $(DMG))" > "$(notdir $(DMG)).sha256"
	rm -rf "$(DMG_STAGING)"
	@echo 'Ready to install: $(DMG)'

release:
	@$(MAKE) test
	@$(MAKE) sign
	@$(MAKE) notarize
	@$(MAKE) verify
	@$(MAKE) dmg

release-all:
	@$(MAKE) release ARCH=arm64
	@$(MAKE) release ARCH=x86_64

clean-dist:
	rm -f "$(UPLOAD_ARCHIVE)" "$(FINAL_ARCHIVE)" "$(FINAL_ARCHIVE).sha256" \
		"$(NOTARY_RESULT)" "$(NOTARY_LOG)" "$(DMG)" "$(DMG).sha256" \
		"$(DMG_NOTARY_RESULT)" "$(DMG_NOTARY_LOG)"
	rm -rf "$(DMG_STAGING)"
