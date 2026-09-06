#!/usr/bin/env bash
## Bounded compressed swap for desktop and gaming memory pressure
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(zram-generator)

# The generator's upstream defaults size this to half of RAM, capped at 4 GiB.
# No VM sysctls are overridden; the kernel remains responsible for policy.
module_apply() {
	file_write /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
EOF
}

module_entrypoint "$@"
