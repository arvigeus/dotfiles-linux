#!/usr/bin/env bash
## System web-application launcher helper.

# Usage: webapp_install NAME URL BIN CATEGORIES [BROWSER]
webapp_install() {
	local name=${1:?name required}
	local url=${2:?URL required}
	local bin=${3:?launcher name required}
	local categories=${4:-Network;WebBrowser;}
	local browser=${5:-chromium}
	local slug=${bin//[^A-Za-z0-9._-]/-}
	local browser_path

	[[ $bin == "$slug" && $bin != .* && $bin != */* ]] || {
		printf 'Invalid web-app launcher name: %s\n' "$bin" >&2
		return 1
	}
	[[ $url == https://* ]] || {
		printf 'Web-app URL must use HTTPS: %s\n' "$url" >&2
		return 1
	}
	browser_path=$(command -v "$browser") || {
		printf 'Web-app browser is not installed: %s\n' "$browser" >&2
		return 1
	}

	file_write -m 0755 "/usr/local/bin/$bin" <<EOF
#!/bin/sh
profile="\${XDG_DATA_HOME:-\$HOME/.local/share}/webapps/$slug/profile"
mkdir -p "\$profile"
exec $browser_path --class=webapp-$slug --user-data-dir="\$profile" --new-window --app='$url' "\$@"
EOF

	file_write "/usr/share/applications/webapp-$slug.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=/usr/local/bin/$bin %U
Icon=web-browser
Categories=$categories
Terminal=false
StartupNotify=true
StartupWMClass=webapp-$slug
EOF
}
