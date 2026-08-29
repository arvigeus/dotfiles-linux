#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r file; do
	bash -n "$PROJECT_ROOT/$file"
done < <(cd "$PROJECT_ROOT" && rg --files -g '*.sh' | sort)

bash -n "$PROJECT_ROOT/modules/gaming/system-gaming-session"
bash -n "$PROJECT_ROOT/modules/hardware/devices/system-g14-observe"
[[ $(bash "$PROJECT_ROOT/modules/hardware/devices/system-g14-observe" --help) == *'only reads system state'* ]]
rg -q '^### Reintroduction gate$' "$PROJECT_ROOT/AGENTS.md"
if command -v desktop-file-validate >/dev/null; then
	desktop-file-validate "$PROJECT_ROOT/modules/gaming/system-gaming.desktop"
fi

first_claude_command=$(awk '!/^#!/ && !/^[[:space:]]*#/ && NF { print; exit }' \
	"$PROJECT_ROOT/modules/ai/claude.sh")
[[ $first_claude_command == 'exit 0' ]] || {
	printf 'Claude module must remain disabled with an early exit\n' >&2
	exit 1
}

while IFS= read -r file; do
	relative=${file#modules/00_init/}
	if [[ $relative == */* || ! $relative =~ ^[0-9]{2}_[a-zA-Z0-9._-]+\.sh$ ]]; then
		printf 'Init modules must be flat and numerically named: %s\n' "$file" >&2
		exit 1
	fi
done < <(cd "$PROJECT_ROOT" && rg --files modules/00_init -g '*.sh' | sort)

while IFS= read -r file; do
	if ! rg -q 'source .*lib/module\.sh' "$PROJECT_ROOT/$file"; then
		printf 'Module does not load lib/module.sh: %s\n' "$file" >&2
		exit 1
	fi
done < <(cd "$PROJECT_ROOT" && rg --files modules -g '*.sh' | sort)

if rg -n 'pkg_from_source' "$PROJECT_ROOT/lib" "$PROJECT_ROOT/modules"; then
	printf 'Ad-hoc source installation remains; use a native recipe or direct module setup\n' >&2
	exit 1
fi

while IFS= read -r spec; do
	package=${spec#arch:pkgbuild/}
	[[ -f "$PROJECT_ROOT/packages/arch/$package/PKGBUILD" ]] || {
		printf 'Missing PKGBUILD for %s\n' "$spec" >&2
		exit 1
	}
done < <(rg --no-filename --only-matching 'arch:pkgbuild/[a-zA-Z0-9@._+-]+' \
	"$PROJECT_ROOT/modules" | sort -u)

while IFS= read -r spec; do
	package=${spec#fedora:rpmspec/}
	[[ -f "$PROJECT_ROOT/packages/fedora/$package/$package.spec" ]] || {
		printf 'Missing RPM spec for %s\n' "$spec" >&2
		exit 1
	}
	[[ -f "$PROJECT_ROOT/packages/fedora/$package/sources.sha256" ]] || {
		printf 'Missing RPM source checksums for %s\n' "$spec" >&2
		exit 1
	}
done < <(rg --no-filename --only-matching 'fedora:rpmspec/[a-zA-Z0-9@._+-]+' \
	"$PROJECT_ROOT/modules" | sort -u)

for recipe in "$PROJECT_ROOT"/packages/arch/*/PKGBUILD; do
	[[ -e $recipe ]] || continue
	package=${recipe%/PKGBUILD}
	package=${package##*/}
	rg -Fq "arch:pkgbuild/$package" "$PROJECT_ROOT/modules" || {
		printf 'Unreferenced PKGBUILD: %s\n' "$recipe" >&2
		exit 1
	}
done

for recipe in "$PROJECT_ROOT"/packages/fedora/*/*.spec; do
	[[ -e $recipe ]] || continue
	package=${recipe##*/}
	package=${package%.spec}
	rg -Fq "fedora:rpmspec/$package" "$PROJECT_ROOT/modules" || {
		printf 'Unreferenced RPM spec: %s\n' "$recipe" >&2
		exit 1
	}
done

if rg -n 'PROJECT_ROOT/distros/|arch:(local|multilib/lib32-)|pm/(arch|fedora)\.sh|_aur-build\.sh' \
	"$PROJECT_ROOT" --glob '!tests/static.sh'; then
	printf 'Obsolete package layout reference found\n' >&2
	exit 1
fi

if rg -n 'powerstation|steamos-manager|inputplumber|opengamepadui|vulkan-low-latency|linux-ogc|fedora:ogc' \
	"$PROJECT_ROOT/modules" \
	--glob '!**/gaming/README.md' \
	--glob '!**/gaming/upstream-research.yaml'; then
	printf 'Removed gaming-stack component is still referenced by a module\n' >&2
	exit 1
fi

printf 'static contracts: ok\n'
