#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r file; do
	bash -n "$PROJECT_ROOT/$file"
done < <(cd "$PROJECT_ROOT" && rg --files -g '*.sh' | sort)

while IFS= read -r file; do
	if ! rg -q 'source .*lib/module\.sh' "$PROJECT_ROOT/$file"; then
		printf 'Module does not load lib/module.sh: %s\n' "$file" >&2
		exit 1
	fi
done < <(cd "$PROJECT_ROOT" && rg --files modules -g '*.sh' | sort)

if rg -n 'PROJECT_ROOT/distros/|arch:(local|multilib/lib32-)|pm/(arch|fedora)\.sh|_aur-build\.sh' \
	"$PROJECT_ROOT" --glob '!tests/static.sh'; then
	printf 'Obsolete package layout reference found\n' >&2
	exit 1
fi

printf 'static contracts: ok\n'
