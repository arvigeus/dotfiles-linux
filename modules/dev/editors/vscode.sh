#!/usr/bin/env bash
## Visual Studio Code
## https://code.visualstudio.com/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	arch:code
	fedora:vscode/code
)

pkg_install "${packages[@]}"

# Base VSCode settings (extension-specific settings are merged later)
read -r -d '' base_settings <<'EOF' || true
{
  "update.mode": "none",
  "window.titleBarStyle": "custom",
  "workbench.colorTheme": "One Dark Pro Mix",
  "editor.fontFamily": "'FiraCode Nerd Font', 'FiraCode Nerd Font Mono', 'monospace', monospace",
  "editor.inlineSuggest.enabled": true,

  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableCommitSigning": true
}
EOF

# Key: extension name; Value: settings
declare -A extensions=(
	# Essentials
	["mikestead.dotenv"]=''
	["editorconfig.editorconfig"]=''

	# Interface Improvements
	["eamodio.gitlens"]=''
	["usernamehw.errorlens"]='{
	  "errorLens.gutterIconsEnabled": true,
      "errorLens.messageMaxChars": 0
	}'
	["pflannery.vscode-versionlens"]=''
	["yoavbls.pretty-ts-errors"]=''
	["wix.vscode-import-cost"]=''
	["gruntfuggly.todo-tree"]='{
      "todo-tree.highlights.customHighlight": {
        "TODO": {
          "type": "text",
          "foreground": "#000000",
          "background": "#00FF00",
          "iconColour": "#00FF00",
          "icon": "shield-check",
          "gutterIcon": true
        },
        "FIXME": {
          "type": "text",
          "foreground": "#000000",
          "background": "#FFFF00",
          "iconColour": "#FFFF00",
          "icon": "shield",
          "gutterIcon": true
        },
        "HACK": {
          "type": "text",
          "foreground": "#000000",
          "background": "#FF0000",
          "iconColour": "#FF0000",
          "icon": "shield-x",
          "gutterIcon": true
        },
        "BUG": {
          "type": "text",
          "foreground": "#000000",
          "background": "#FFA500",
          "iconColour": "#FFA500",
          "icon": "bug",
          "gutterIcon": true
        }
      }
    }'

	# AI
	["Anthropic.claude-code"]=''
	["openai.chatgpt"]=''
	["kilocode.Kilo-Code"]=''

	# Color schemes (workbench.colorTheme: "One Dark Pro Mix")
	["zhuangtongfa.material-theme"]=''

	# Docker (Podman)
	["docker.docker"]=''

	# Web Dev
	["biomejs.biome"]='{
      "[html]": { "editor.defaultFormatter": "biomejs.biome" },
      "[css]": { "editor.defaultFormatter": "biomejs.biome" },
      "[javascript]": { "editor.defaultFormatter": "biomejs.biome" },
      "[json]": { "editor.defaultFormatter": "biomejs.biome" },
      "[jsonc]": { "editor.defaultFormatter": "biomejs.biome" },
      "[typescript]": { "editor.defaultFormatter": "biomejs.biome" },
      "[typescriptreact]": { "editor.defaultFormatter": "biomejs.biome" }
    }'
	["dbaeumer.vscode-eslint"]=''
	["esbenp.prettier-vscode"]='{
      "[markdown]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
      "[scss]": { "editor.defaultFormatter": "esbenp.prettier-vscode" }
    }'
	["csstools.postcss"]=''
	["stylelint.vscode-stylelint"]=''
	["bradlc.vscode-tailwindcss"]=''
	["davidanson.vscode-markdownlint"]=''
	["unifiedjs.vscode-mdx"]=''

	# Deno
	["denoland.vscode-deno"]=''

	# GraphQL
	["graphql.vscode-graphql-syntax"]=''
	["graphql.vscode-graphql"]=''

	# Bash
	["mads-hartmann.bash-ide-vscode"]='{
	  "bashIde.shellcheckPath": "/usr/bin/shellcheck"
	}'
	["mkhl.shfmt"]='{
	  "shfmt.executablePath": "/usr/bin/shfmt"
	}'

	# Rust
	["rust-lang.rust-analyzer"]=''
	["vadimcn.vscode-lldb"]=''
	["wcrichton.flowistry"]=''

	# TOML
	["tamasfe.even-better-toml"]=''

	# Just
	["nefrob.vscode-just-syntax"]=''

	# Testing
	["vitest.explorer"]=''
	["ms-playwright.playwright"]=''
	["firefox-devtools.vscode-firefox-debug"]=''
	["ms-vscode.test-adapter-converter"]=''
)

case "$DISTRO" in
fedora) CODE_CONF_DIR="Code" ;;
arch) CODE_CONF_DIR="Code - OSS" ;;
esac

# Merge base settings with extension-specific settings without installing the
# user-local extensions themselves.
vscode_settings=$base_settings
for ext in "${!extensions[@]}"; do
	if [[ -n ${extensions[$ext]} ]]; then
		vscode_settings=$(printf '%s\n%s' "$vscode_settings" "${extensions[$ext]}" | jq -s '.[0] * .[1]')
	fi
done

# Extensions are not installed in the candidate root: they are user-local
# packages and the old post-deploy extension framework is intentionally absent.
# Stage only the merged user settings for home reconciliation.
printf '%s\n' "$vscode_settings" | jq . |
	file_write "$HOME/.config/$CODE_CONF_DIR/User/settings.json"
