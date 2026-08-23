#!/usr/bin/env bash
## Discord desktop client
## https://discord.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"

packages=(
	flathub/com.discordapp.Discord
    #flathub/dev.vencord.Vesktop
)
pkg_install "${packages[@]}"
flatpak_alias discord com.discordapp.Discord

# Safe skeleton default; Discord may replace it in the user's sandbox later.
file_write "$HOME/.var/app/com.discordapp.Discord/config/discord/settings.json" <<'EOF'
{
  "SKIP_HOST_UPDATE": true
}
EOF
