#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN="$PROJECT_ROOT/modules/ai/pi/plugins/system-update"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$PLUGIN" -p 'test_*.py'

# Exercise the module apply phase only inside a disposable home. Package
# declarations are never installed by this test, and existing Pi settings stay.
TEST_HOME=$(mktemp -d)
trap 'rm -rf -- "$TEST_HOME"' EXIT
mkdir -p "$TEST_HOME/.pi/agent"
printf '{"existing":true}\n' >"$TEST_HOME/.pi/agent/settings.json"
for distro in arch fedora; do
	manager=pacman
	[[ $distro != fedora ]] || manager=dnf
	env HOME="$TEST_HOME" SETUP_ROOT="$PROJECT_ROOT" MODULE_DIR="$PROJECT_ROOT/modules/ai/pi" \
		MODULE_PHASE=apply DISTRO="$distro" PACKAGE_MANAGER="$manager" \
		bash "$PROJECT_ROOT/modules/ai/pi/module.sh"
	cmp "$PLUGIN/index.ts" "$TEST_HOME/.pi/agent/extensions/system-update/index.ts"
	cmp "$PLUGIN/backend.py" "$TEST_HOME/.pi/agent/extensions/system-update/backend.py"
	grep -Fq '"existing":true' "$TEST_HOME/.pi/agent/settings.json"
done
printf 'system-update module installation: ok\n'

# Runtime contract tests use the already-installed Pi APIs; never install deps
# or execute package-manager updates from the test suite.
agent_dir=${PI_TEST_AGENT_DIR:-}
if [[ -z $agent_dir ]] && command -v npm >/dev/null; then
	agent_dir="$(npm root -g)/@earendil-works/pi-coding-agent"
fi
if [[ ! -f $agent_dir/dist/index.js ]] && command -v pi >/dev/null; then
	agent_dir=$(dirname -- "$(dirname -- "$(readlink -f -- "$(command -v pi)")")")
fi
if command -v node >/dev/null && [[ -f $agent_dir/dist/index.js ]]; then
	PI_TEST_AGENT_DIR="$agent_dir" node "$PLUGIN/test_extension.mjs"
	if command -v tsc >/dev/null && [[ -f $agent_dir/node_modules/@types/node/package.json ]]; then
		# Resolve types against the same installed Pi as the runtime tests; no
		# dependency installation or machine-specific paths committed to the repo.
		node --input-type=module - "$agent_dir" "$PLUGIN" "$TEST_HOME/tsconfig.json" <<'JS'
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
const [agent, plugin, output] = process.argv.slice(2).map(path => resolve(path));
const options = {
  strict: true, noEmit: true, skipLibCheck: true,
  target: 'ES2022', module: 'NodeNext', moduleResolution: 'NodeNext',
  types: ['node'], typeRoots: [join(agent, 'node_modules/@types')],
  paths: {
    '@earendil-works/pi-coding-agent': [join(agent, 'dist/index.d.ts')],
    '@earendil-works/pi-ai': [join(agent, 'node_modules/@earendil-works/pi-ai/dist/index.d.ts')],
    '@earendil-works/pi-tui': [join(agent, 'node_modules/@earendil-works/pi-tui/dist/index.d.ts')],
    typebox: [join(agent, 'node_modules/typebox/build/index.d.mts')],
  },
};
writeFileSync(output, JSON.stringify({ compilerOptions: options, files: [join(plugin, 'index.ts')] }));
JS
		tsc --project "$TEST_HOME/tsconfig.json"
		printf 'system:update strict TypeScript: ok\n'
	else
		printf 'system:update strict TypeScript: skipped (tsc/Node types unavailable)\n'
	fi
else
	printf 'system-update extension runtime: skipped (set PI_TEST_AGENT_DIR to an installed Pi package)\n'
fi
