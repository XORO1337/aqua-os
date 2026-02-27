# AquaOS — Makefile

.PHONY: help install check backup restore uninstall lint

# Default target: show help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Usage: make <target>"

install: ## Run the full installer (interactive)
	@bash install.sh

check: ## Verify dependencies, fonts, and themes are installed
	@echo "Checking dependencies..."
	@command -v hyprland    >/dev/null && echo "  [✓] hyprland"    || echo "  [✗] hyprland (missing)"
	@command -v quickshell  >/dev/null && echo "  [✓] quickshell"  || echo "  [✗] quickshell (missing)"
	@command -v ags         >/dev/null && echo "  [✓] ags"         || echo "  [✗] ags (missing)"
	@command -v swww        >/dev/null && echo "  [✓] swww"        || echo "  [✗] swww (missing)"
	@command -v matugen     >/dev/null && echo "  [✓] matugen"     || echo "  [✗] matugen (missing)"
	@command -v ghostty     >/dev/null && echo "  [✓] ghostty"     || echo "  [✗] ghostty (optional)"
	@command -v kitty       >/dev/null && echo "  [✓] kitty"       || echo "  [✗] kitty (optional)"
	@command -v alacritty   >/dev/null && echo "  [✓] alacritty"   || echo "  [✗] alacritty (optional)"
	@command -v brightnessctl>/dev/null && echo "  [✓] brightnessctl" || echo "  [✗] brightnessctl"
	@command -v playerctl   >/dev/null && echo "  [✓] playerctl"   || echo "  [✗] playerctl"
	@command -v jq          >/dev/null && echo "  [✓] jq"          || echo "  [✗] jq"
	@command -v socat       >/dev/null && echo "  [✓] socat"       || echo "  [✗] socat"
	@command -v inotifywait >/dev/null && echo "  [✓] inotifywait" || echo "  [✗] inotifywait"
	@echo ""
	@echo "Checking fonts..."
	@fc-list | grep -qi "Inter" && echo "  [✓] Inter" || echo "  [✗] Inter"
	@fc-list | grep -qi "JetBrains Mono Nerd" && echo "  [✓] JetBrains Mono Nerd Font" || echo "  [✗] JetBrains Mono Nerd Font"
	@fc-list | grep -qi "Symbols Nerd Font"   && echo "  [✓] Symbols Nerd Font"        || echo "  [✗] Symbols Nerd Font"
	@echo ""
	@echo "Checking themes..."
	@[ -d "$$HOME/.local/share/themes/WhiteSur-Dark" ] && echo "  [✓] WhiteSur GTK theme" || echo "  [✗] WhiteSur GTK theme"
	@[ -d "$$HOME/.local/share/icons/WhiteSur-dark" ]  && echo "  [✓] WhiteSur icon theme" || echo "  [✗] WhiteSur icon theme"
	@[ -d "$$HOME/.local/share/icons/WhiteSur-cursors" ] && echo "  [✓] WhiteSur cursor theme" || echo "  [✗] WhiteSur cursor theme"

backup: ## Backup current AquaOS configurations
	@ts=$$(date +%Y%m%d_%H%M%S); \
	bdir="$$HOME/.config/aqua-os-backup-$$ts"; \
	mkdir -p "$$bdir"; \
	for d in hypr quickshell ags ghostty kitty alacritty matugen firefox; do \
		[ -d "$$HOME/.config/$$d" ] && cp -r "$$HOME/.config/$$d" "$$bdir/"; \
	done; \
	echo "Backup saved to $$bdir"

restore: ## Restore from the latest backup
	@latest=$$(ls -1dt "$$HOME/.config/aqua-os-backup-"* 2>/dev/null | head -1); \
	[ -n "$$latest" ] || { echo "No backup found."; exit 1; }; \
	echo "Restoring from $$latest..."; \
	for d in "$$latest"/*/; do \
		name=$$(basename "$$d"); \
		cp -r "$$d" "$$HOME/.config/$$name"; \
		echo "  Restored $$name"; \
	done; \
	echo "Restore complete."

uninstall: ## Remove AquaOS shell configs (keeps system packages)
	@echo "Removing AquaOS configurations..."
	@rm -rf "$$HOME/.config/hypr"        && echo "  Removed hypr"
	@rm -rf "$$HOME/.config/quickshell"  && echo "  Removed quickshell"
	@rm -rf "$$HOME/.config/ags"         && echo "  Removed ags"
	@rm -rf "$$HOME/.config/matugen"     && echo "  Removed matugen"
	@rm -f  "$$HOME/.local/bin/macos-mirror-events.sh" && echo "  Removed event daemon"
	@rm -f  "$$HOME/.local/bin/wallpaper.sh" && echo "  Removed wallpaper script"
	@echo "Uninstall complete. Restart to return to a plain Hyprland setup."

lint: ## Type-check AGS TypeScript widgets
	@cd ags && tsc --noEmit && echo "TypeScript: no errors"
