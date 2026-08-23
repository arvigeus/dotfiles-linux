#!/usr/bin/env bash
## GravityMark — cross-platform GPU benchmark
## https://gravitymark.tellusim.com/
##
## Upstream does not publish a stable release API or checksums. This module
## intentionally resolves the latest x86-64 self-installer at build time.
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

pkg_install curl

install_gravity_mark() (
	set -Eeuo pipefail
	local page_url=https://gravitymark.tellusim.com/
	local tmpdir page installer_url installer
	tmpdir=$(mktemp -d)
	trap 'rm -rf -- "$tmpdir"' EXIT
	page="$tmpdir/index.html"
	installer="$tmpdir/GravityMark.run"

	curl --fail --silent --show-error --location \
		--output "$page" "$page_url"
	installer_url=$(
		grep -Eo \
			'https?://tellusim[.]com/download/GravityMark_[0-9.]+[.]run|/download/GravityMark_[0-9.]+[.]run|download/GravityMark_[0-9.]+[.]run' \
			"$page" |
			sed 's|^/download|https://tellusim.com/download|; s|^download|https://tellusim.com/download|' |
			head -n 1
	)
	[[ $installer_url == https://tellusim.com/download/GravityMark_*.run ]] || {
		printf 'Could not resolve the latest GravityMark x86-64 installer\n' >&2
		return 1
	}

	curl --fail --silent --show-error --location \
		--output "$installer" "$installer_url"
	install -Dm755 "$installer" /opt/gravity-mark/GravityMark.run
	file_write /usr/local/bin/gravity-mark 0755 <<'EOF'
#!/usr/bin/env bash
exec /opt/gravity-mark/GravityMark.run "$@"
EOF
)

install_gravity_mark
