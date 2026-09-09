# wgsplit — everything you need day to day.
.DEFAULT_GOAL := help
SHELL := /bin/bash
APP := dist/WGSplit.app
# Ad-hoc identity by default; a real one enables notarization.
#   make release SIGN_ID="Developer ID Application: NAME (TEAMID)" \
#     APPLE_ID=you@example.com TEAM_ID=TEAMID APP_PW=app-specific-password
VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo 0.0.0)
SIGN_ID ?= -
APPLE_ID ?=
TEAM_ID ?=
APP_PW ?=
export VERSION SIGN_ID

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk -F':.*?## ' '{printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: singbox
singbox: Resources/sing-box ## Vendor the pinned sing-box
Resources/sing-box:
	@./Scripts/vendor-singbox.sh

.PHONY: build
build: singbox ## Build everything and assemble WGSplit.app
	@swift build -c release
	@./Scripts/bundle.sh

.PHONY: dmg
dmg: build ## Package WGSplit.app into a distributable disk image
	@./Scripts/make-dmg.sh

.PHONY: dmg
dmg: build ## Package WGSplit.app into a distributable disk image
	@./Scripts/make-dmg.sh

.PHONY: notarize
notarize: dmg ## Submit the disk image to Apple, then staple app and image
	@if [ "$(SIGN_ID)" = "-" ]; then \
	  echo "notarization needs a Developer ID: make notarize SIGN_ID=..."; exit 1; \
	fi
	@xcrun notarytool submit dist/WGSplit.dmg \
	  --apple-id "$(APPLE_ID)" --team-id "$(TEAM_ID)" --password "$(APP_PW)" --wait
	@xcrun stapler staple $(APP)
	@xcrun stapler staple dist/WGSplit.dmg
	@xcrun stapler validate $(APP)

.PHONY: release
release: notarize ## Signed, notarized app and disk image ready to publish
	@echo "release $(VERSION) ready in dist/"

.PHONY: run
run: kill build ## Rebuild and relaunch the app (kills the running copy first)
	@open $(APP)
	@echo "launched $(APP) — look for the shield in the menu bar"

.PHONY: kill
kill: ## Quit a running WGSplit.app
	@pkill -f '$(APP)/Contents/MacOS/WGSplitApp' 2>/dev/null && echo "quit running app" || true

.PHONY: install
install: build ## Install the daemon (prompts for your password)
	@sudo ./Scripts/install-daemon.sh

.PHONY: uninstall
uninstall: ## Remove the daemon and stop the app
	@sudo ./Scripts/uninstall-daemon.sh
	@$(MAKE) --no-print-directory kill

.PHONY: test
test: singbox ## Run the test suite
	@swift test

.PHONY: status
status: ## Show daemon, socket and tunnel state
	@echo "daemon:  $$(pgrep -lf PrivilegedHelperTools/wgsplit/wgsplitd || echo 'not running')"
	@echo "sing-box: $$(pgrep -lf 'PrivilegedHelperTools/wgsplit/sing-box' || echo 'not running')"
	@echo "socket:  $$(ls -l /var/run/wgsplit.sock 2>/dev/null || echo 'absent')"
	@printf '{"status":{}}\n' | nc -U /var/run/wgsplit.sock 2>/dev/null | head -c 400 || echo "(no reply)"
	@echo

.PHONY: logs
logs: ## Tail the daemon log
	@sudo tail -f /var/log/wgsplit.log

.PHONY: clean
clean: ## Remove build output
	@rm -rf .build dist
