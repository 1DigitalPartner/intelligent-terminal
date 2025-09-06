# Makefile for releasing intelligent-terminal via Homebrew
# Usage:
#   make release VERSION=0.1.1
# Prereqs: gh (GitHub CLI), git, python3, build, sed (macOS), Homebrew logged-in SSH

# ----- CONFIG -----
OWNER              ?= 1DigitalPartner
PROJECT_REPO       ?= $(OWNER)/intelligent-terminal
TAP_REPO           ?= $(OWNER)/homebrew-intelligent-terminal
# Local checkout of the tap repo (adjust if different)
TAP_DIR            ?= $$HOME/Downloads/homebrew-intelligent-terminal-tap

# Version must be provided: make release VERSION=0.1.1
VERSION            ?=
PKG_NAME           := intelligent_terminal
WHEEL              := dist/$(PKG_NAME)-$(VERSION)-py3-none-any.whl
SDIST              := dist/$(PKG_NAME)-$(VERSION).tar.gz
RELEASE_TAG        := v$(VERSION)
RELEASE_TITLE      := $(RELEASE_TAG)
WHEEL_URL          := https://github.com/$(PROJECT_REPO)/releases/download/$(RELEASE_TAG)/$(PKG_NAME)-$(VERSION)-py3-none-any.whl

PYTHON_BIN         ?= python3
VENV               ?= .venv

# ----- GUARDS -----
ifndef VERSION
$(error VERSION is required, e.g. make release VERSION=0.1.1)
endif

# ----- PHONY -----
.PHONY: build wheel sdist tag push-code push-tag gh-release gh-upload checksum tap-update tap-commit tap-push brew-test release clean

# 0) Build (sdist + wheel)
build:
	@echo "==> Building sdist + wheel for $(RELEASE_TAG)"
	$(PYTHON_BIN) -m venv $(VENV)
	. $(VENV)/bin/activate && pip install -U pip build
	. $(VENV)/bin/activate && python -m build
	@ls -la dist

wheel:
	@echo "==> Building wheel $(WHEEL)"
	$(PYTHON_BIN) -m venv $(VENV)
	. $(VENV)/bin/activate && pip install -U pip build
	. $(VENV)/bin/activate && python -m build --wheel
	@test -f "$(WHEEL)" || (echo "Wheel not found: $(WHEEL)"; exit 1)

sdist:
	@echo "==> Building sdist $(SDIST)"
	$(PYTHON_BIN) -m venv $(VENV)
	. $(VENV)/bin/activate && pip install -U pip build
	. $(VENV)/bin/activate && python -m build --sdist
	@test -f "$(SDIST)" || (echo "sdist not found: $(SDIST)"; exit 1)

# 1) Git tag + push
push-code:
	@git add .
	@git commit -m "chore(release): $(RELEASE_TAG)" || true
	git push -u origin $$(git rev-parse --abbrev-ref HEAD)

tag:
	git tag $(RELEASE_TAG) || true
	git push origin $(RELEASE_TAG)

# 2) GitHub release + upload artifacts
gh-release:
	@echo "==> Creating/updating GitHub release $(RELEASE_TAG)"
	gh release view $(RELEASE_TAG) >/dev/null 2>&1 || gh release create $(RELEASE_TAG) --title "$(RELEASE_TITLE)" --notes "Release $(RELEASE_TAG)"

gh-upload: wheel sdist
	@echo "==> Uploading artifacts to GitHub release"
	gh release upload $(RELEASE_TAG) "$(WHEEL)" --clobber
	gh release upload $(RELEASE_TAG) "$(SDIST)" --clobber

# 3) Compute SHA256 of the WHEEL (used in formula)
checksum: wheel
	@echo "==> Calculating SHA256 for wheel"
	@shasum -a 256 "$(WHEEL)" | awk '{print $$1}' > .wheel.sha256
	@echo "WHEEL_SHA256=$$(cat .wheel.sha256)"

# 4) Update tap formula (URL + SHA + keep custom install)
tap-update: checksum
	@test -d "$(TAP_DIR)" || (echo "Tap dir not found: $(TAP_DIR). Clone it first: git clone git@github.com:$(TAP_REPO).git $(TAP_DIR)"; exit 1)
	@echo "==> Updating formula in $(TAP_DIR)"
	@WHEEL_SHA256=$$(cat .wheel.sha256); \
	FILE="$(TAP_DIR)/Formula/intelligent-terminal.rb"; \
	/usr/bin/sed -i '' "s|^  url \".*\"|  url \"$(WHEEL_URL)\"|g" $$FILE; \
	/usr/bin/sed -i '' "s|^  sha256 \".*\"|  sha256 \"$$WHEEL_SHA256\"|g" $$FILE; \
	echo "Updated URL -> $(WHEEL_URL)"; \
	echo "Updated SHA256 -> $$WHEEL_SHA256"

tap-commit:
	@echo "==> Committing formula changes"
	cd "$(TAP_DIR)" && git add Formula/intelligent-terminal.rb && git commit -m "chore(brew): bump to $(RELEASE_TAG) (wheel URL + sha256)" || true

tap-push:
	cd "$(TAP_DIR)" && git push -u origin $$(git rev-parse --abbrev-ref HEAD)

# 5) Test via brew (re-tap fresh and install)
brew-test:
	@echo "==> Re-tapping and installing via Homebrew"
	brew uninstall --force intelligent-terminal 2>/dev/null || true
	brew untap $(OWNER)/intelligent-terminal 2>/dev/null || true
	brew tap $(OWNER)/intelligent-terminal
	HOMEBREW_NO_AUTO_UPDATE=1 brew install intelligent-terminal
	@echo "==> Running: intelligent-terminal -h"
	@intelligent-terminal -h || true

# One-shot release pipeline
release: build push-code tag gh-release gh-upload tap-update tap-commit tap-push brew-test
	@echo "✅ Release $(RELEASE_TAG) complete."
	@echo "   URL: $(WHEEL_URL)"
	@echo "   SHA: $$(cat .wheel.sha256)"
	@echo "   Try: intelligent-terminal -h"

clean:
	rm -rf dist *.egg-info $(VENV) .wheel.sha256
