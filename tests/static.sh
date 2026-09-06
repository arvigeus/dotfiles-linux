#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r file; do
	bash -n "$PROJECT_ROOT/$file"
done < <(cd "$PROJECT_ROOT" && rg --files -g '*.sh' | sort)

gaming_session="$PROJECT_ROOT/modules/gaming/gamescope-session/files/usr/local/bin/system-gaming-session"
g14_observer="$PROJECT_ROOT/modules/hardware/devices/zephyrus/files/usr/local/bin/system-g14-observe"
ufw_runner="$PROJECT_ROOT/modules/system/security/ufw/files/usr/local/libexec/system-apply-ufw-rules"
libvirt_ufw="$PROJECT_ROOT/modules/system/virtualization/virt-manager/files/usr/local/libexec/system-ufw-rules.d/30-libvirt"
ssh_ufw="$PROJECT_ROOT/modules/system/security/ssh/server/files/usr/local/libexec/system-ufw-rules.d/10-openssh"
bash -n "$gaming_session"
bash -n "$g14_observer"
bash -n "$ufw_runner"
bash -n "$libvirt_ufw"
bash -n "$ssh_ufw"
[[ $(bash "$g14_observer" --help) == *'only reads system state'* ]]
[[ $(stat -c %a "$gaming_session") == 755 ]]
[[ $(stat -c %a "$g14_observer") == 755 ]]
[[ $(stat -c %a "$ufw_runner") == 755 ]]
[[ $(stat -c %a "$libvirt_ufw") == 755 ]]
[[ $(stat -c %a "$ssh_ufw") == 755 ]]
rg -q "printf '%s\\\\n' /etc/machine-id" "$PROJECT_ROOT/installer/preserve.sh" || {
	printf 'Clean-root rebuilds must preserve /etc/machine-id\n' >&2
	exit 1
}
if [[ -e $PROJECT_ROOT/modules/base/machine-identity.sh ]]; then
	printf 'Machine identity is an installer invariant, not a selectable module\n' >&2
	exit 1
fi
rg -q "preserve_path '/etc/ssh/ssh_host_\\*'" \
	"$PROJECT_ROOT/modules/system/security/ssh/server/module.sh" || {
	printf 'The SSH module must retain its host identity across rebuilds\n' >&2
	exit 1
}
rg -q '^TimeoutStartSec=60s$' \
	"$PROJECT_ROOT/modules/system/security/ufw/files/etc/systemd/system/system-ufw-rules.service" || {
	printf 'Feature-owned UFW rule application must have a finite deadline\n' >&2
	exit 1
}
rg -q '^Requires=system-ufw-rules.service$' \
	"$PROJECT_ROOT/modules/system/virtualization/virt-manager/files/etc/systemd/system/libvirtd.service.d/ufw.conf" || {
	printf 'libvirtd must not start when required firewall policy failed\n' >&2
	exit 1
}
rg -q '^### Reintroduction gate$' "$PROJECT_ROOT/AGENTS.md"
rg -q '^[[:space:]]*target_namespace /usr/bin/env' "$PROJECT_ROOT/installer/modules.sh" || {
	printf 'Modules must run below a pivot root so nested sandboxes work\n' >&2
	exit 1
}
rg -q '^pivot_root \. \.$' "$PROJECT_ROOT/installer/pivot-root.sh" || {
	printf 'Module namespace helper must replace the chroot mount root\n' >&2
	exit 1
}
rg -q '^mount --rbind "\$target_root" "\$target_root"$' \
	"$PROJECT_ROOT/installer/pivot-root.sh" || {
	printf 'Module namespace helper must preserve candidate submounts\n' >&2
	exit 1
}
if command -v desktop-file-validate >/dev/null; then
	desktop-file-validate \
		"$PROJECT_ROOT/modules/gaming/gamescope-session/files/usr/share/wayland-sessions/system-gaming.desktop"
fi

if rg -Fq 'ai/claude' "$PROJECT_ROOT/hosts"; then
	printf 'Claude module must not be selected by a host without review\n' >&2
	exit 1
fi

while IFS= read -r file; do
	if ! rg -q 'source .*lib/module\.sh' "$PROJECT_ROOT/$file"; then
		printf 'Module does not load lib/module.sh: %s\n' "$file" >&2
		exit 1
	fi
done < <(cd "$PROJECT_ROOT" && rg --files modules -g '*.sh' \
	-g '!**/sources/**' -g '!**/packages/**' | sort)

while IFS= read -r file; do
	rg -q 'module_entrypoint' "$PROJECT_ROOT/$file" || {
		printf 'Module does not use module_entrypoint: %s\n' "$file" >&2
		exit 1
	}
done < <(cd "$PROJECT_ROOT" && rg --files modules -g '*.sh' \
	-g '!**/sources/**' -g '!**/packages/**' | sort)

if rg -n 'pkg_install|pkg_repo_enable' "$PROJECT_ROOT/modules" \
	--glob '*.sh' --glob '!**/sources/**' --glob '!**/packages/**'; then
	printf 'Modules must declare packages and sources instead of installing them\n' >&2
	exit 1
fi

if find "$PROJECT_ROOT/modules" -path '*/files/*' -type l -print -quit | grep -q .; then
	printf 'Module files overlays must not contain symlinks\n' >&2
	exit 1
fi

if rg -n 'pkg_from_source' "$PROJECT_ROOT/lib" "$PROJECT_ROOT/modules"; then
	printf 'Ad-hoc source installation remains; use a native recipe or direct module setup\n' >&2
	exit 1
fi

if rg -n 'github_download|file_install_tree' "$PROJECT_ROOT/modules" \
	--glob '*.sh' --glob '!**/sources/**' --glob '!**/packages/**'; then
	printf 'Modules must install upstream system payloads through package recipes\n' >&2
	exit 1
fi

while IFS=: read -r file _ spec; do
	package=${spec#arch:pkgbuild/}
	module_dir=$(dirname -- "$PROJECT_ROOT/$file")
	[[ -f "$module_dir/packages/arch/$package/PKGBUILD" ]] || {
		printf 'Missing module-local PKGBUILD for %s in %s\n' "$spec" "$file" >&2
		exit 1
	}
done < <(cd "$PROJECT_ROOT" && rg -n --only-matching \
	'arch:pkgbuild/[a-zA-Z0-9@._+-]+' modules --glob '*.sh')

while IFS=: read -r file _ spec; do
	package=${spec#fedora:rpmspec/}
	module_dir=$(dirname -- "$PROJECT_ROOT/$file")
	[[ -f "$module_dir/packages/fedora/$package/$package.spec" ]] || {
		printf 'Missing module-local RPM spec for %s in %s\n' "$spec" "$file" >&2
		exit 1
	}
	[[ -f "$module_dir/packages/fedora/$package/sources.sha256" ]] || {
		printf 'Missing RPM source checksums for %s in %s\n' "$spec" "$file" >&2
		exit 1
	}
done < <(cd "$PROJECT_ROOT" && rg -n --only-matching \
	'fedora:rpmspec/[a-zA-Z0-9@._+-]+' modules --glob '*.sh')

while IFS= read -r relative; do
	recipe="$PROJECT_ROOT/$relative"
	package=${recipe%/PKGBUILD}
	package=${package##*/}
	rg -Fq "arch:pkgbuild/$package" "$PROJECT_ROOT/modules" || {
		printf 'Unreferenced PKGBUILD: %s\n' "$recipe" >&2
		exit 1
	}
done < <(cd "$PROJECT_ROOT" && rg --files modules -g 'PKGBUILD')

while IFS= read -r relative; do
	recipe="$PROJECT_ROOT/$relative"
	package=${recipe##*/}
	package=${package%.spec}
	rg -Fq "fedora:rpmspec/$package" "$PROJECT_ROOT/modules" || {
		printf 'Unreferenced RPM spec: %s\n' "$recipe" >&2
		exit 1
	}
done < <(cd "$PROJECT_ROOT" && rg --files modules -g '*.spec')

if rg -n 'PROJECT_ROOT/distros/|arch:(local|multilib/lib32-)|sources/(arch|fedora)\.sh|_aur-build\.sh' \
	"$PROJECT_ROOT" --glob '!tests/static.sh'; then
	printf 'Obsolete package layout reference found\n' >&2
	exit 1
fi

rg -Fq 'x86-64-v3 (supported, searched)' \
	"$PROJECT_ROOT/modules/base/package-sources.sh" || {
	printf 'ALHP selection must retain its x86-64-v3 CPU gate\n' >&2
	exit 1
}

if rg -n 'powerstation|steamos-manager|inputplumber|opengamepadui|vulkan-low-latency|linux-ogc|fedora:ogc' \
	"$PROJECT_ROOT/modules" \
	--glob '!**/gaming/README.md' \
	--glob '!**/gaming/upstream-research.yaml'; then
	printf 'Removed gaming-stack component is still referenced by a module\n' >&2
	exit 1
fi

printf 'static contracts: ok\n'
