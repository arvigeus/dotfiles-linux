#!/usr/bin/env bash
## Arch managed kernel
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
[[ $DISTRO == arch ]] || exit 0

# The stock kernel makes pacstrap's initial chroot self-contained. Replace it
# only after the OGC source can be enabled by the normal package-plugin path.
pkg_install arch:ogc/linux-ogc
if pkg_is_installed arch:linux; then
	pkg_remove arch:linux
fi
file_write /etc/system/kernel-package <<'EOF'
linux-ogc
EOF
