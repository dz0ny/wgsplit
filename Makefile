# wgsplit — everything you need day to day.
.DEFAULT_GOAL := help
SHELL := /bin/bash
APP := dist/WGSplit.app

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
	@swift build -c release --product WGSplitApp --product wgsplitd
	@./Scripts/bundle.sh

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
