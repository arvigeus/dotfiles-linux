#!/usr/bin/env bash
## English and Bulgarian phonetic, switched with Alt+Shift.
set -Eeuo pipefail
source "$SETUP_ROOT/lib/module.sh"
module_check() { [[ ${DESKTOP:-} == plasma || ${DESKTOP:-} == hyprland ]]; }
requires=(hardware/keyboard/input-method/common)
if [[ ${DESKTOP:-} == plasma ]]; then
	packages=(arch:kconfig fedora:kf6-kconfig)
fi
module_apply() {
	if [[ $DESKTOP == hyprland ]]; then
		# Consume the shell's public provider interface; it knows nothing about
		# this controller, its unit, or this repository's module layout.
		file_write "$HOME/.config/zephyrus-shell/input-language.json" <<'JSON'
{"command":["/usr/local/bin/system-input-method"]}
JSON
		home_strategy .config/zephyrus-shell/input-language.json replace never
		file_write "$HOME/.config/zephyrus-shell/input-method.lua" <<'LUA'
-- Owned by hardware/keyboard/input-method/bg. No daemon is started here.
hl.config({ input = { kb_layout = "us,bg", kb_variant = ",phonetic",
    kb_options = "terminate:ctrl_alt_bksp,grp:alt_shift_toggle" } })
LUA
		home_strategy .config/zephyrus-shell/input-method.lua replace never
	else
		# KConfig writes preserve unrelated settings and work in the build root.
		local key value
		while IFS='=' read -r key value; do
			kwriteconfig6 --file "$HOME/.config/kxkbrc" --group Layout --key "$key" "$value"
		done <<'LAYOUT'
DisplayNames=,
LayoutList=us,bg
Options=terminate:ctrl_alt_bksp,grp:alt_shift_toggle
ResetOldOptions=true
SwitchMode=Window
Use=true
VariantList=,phonetic
LAYOUT
		home_strategy .config/kxkbrc ini unchanged
	fi
}
module_entrypoint "$@"
