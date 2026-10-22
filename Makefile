# Shortcuts for the common tasks. `make` alone lists them.
# Each target is one line: the real logic lives in the scripts, which you can
# also run directly.

.DEFAULT_GOAL := help
.PHONY: help bootstrap dry-run install uninstall test test-full arch-setup arch-test

help: ## list the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-11s %s\n", $$1, $$2}'

bootstrap: ## install the programs (sudo; apt or pacman)
	scripts/bootstrap.sh

dry-run: ## show what install would change, change nothing
	./install.sh --dry-run

install: ## link home/ into $$HOME (backs up whatever it replaces)
	./install.sh

uninstall: ## remove the links (backups stay)
	./install.sh --uninstall

test: ## all offline checks in a throwaway HOME
	scripts/test.sh

test-full: ## + install vim plugins and test clangd inside vim (network)
	scripts/test.sh --full

arch-setup: ## build the rootless Arch Linux sandbox (~1.5 GB, once)
	scripts/arch-sandbox.sh setup

arch-test: ## run the full tests inside Arch Linux
	scripts/arch-sandbox.sh test --full
