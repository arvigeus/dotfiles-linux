#!/usr/bin/env bash
# shellcheck disable=SC2329 # callbacks invoked by the sourced provider
set -Eeuo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
SETUP_ROOT=$PROJECT_ROOT
DISTRO=arch PROJECT_ID=system
export SETUP_ROOT DISTRO PROJECT_ID TEST_ROOT
source "$PROJECT_ROOT/lib/package.sh"
provider="$PROJECT_ROOT/modules/desktop/hyprland/sources/arch/git-pkgbuild.sh"
mkdir -p "$TEST_ROOT/upstream" "$TEST_ROOT/home"
cat >"$TEST_ROOT/upstream/PKGBUILD" <<'RECIPE'
pkgname=('example-git' 'example-session-git')
pkgver=r1
pkgrel=1
pkgdesc='Fixture external split recipe'
arch=('any')
source=('example::git+https://example.test/upstream.git')
sha256sums=('SKIP')
makedepends=('git')
optdepends=('fixture-native>=1: native optional' 'fixture-aur: AUR optional' 'example-session-git: split output' 'fixture-native: duplicate')
pkgver() { printf "r%s.g%s" "$(git -C "$srcdir/example" rev-list --count HEAD)" "$(git -C "$srcdir/example" rev-parse --short HEAD)"; }
package_example-git() {
    install -Dm644 "$srcdir/example/payload" "$pkgdir/usr/share/example/payload"
}
package_example-session-git() { depends=('example-git'); }
RECIPE
printf 'first\n' >"$TEST_ROOT/upstream/payload"
git -C "$TEST_ROOT/upstream" init -q
git -C "$TEST_ROOT/upstream" add .
git -C "$TEST_ROOT/upstream" -c commit.gpgsign=false -c user.name=Test -c user.email=test@example.test commit -qm initial
# Include uncommitted changes in the explicit local override.
printf 'working tree\n' >"$TEST_ROOT/upstream/payload"
export GIT_PKGBUILD_LOCAL_DIR="$TEST_ROOT/upstream"
export PKGDEST="$TEST_ROOT/packages"
mkdir -p "$PKGDEST"

# Stub only privileged host boundaries. Plan dispatch, source methods, Git,
# working-tree snapshotting, makepkg and native package archives are real.
_pkg_plugin_call() (
	# shellcheck disable=SC1090 # actual source provider under test
	source "$1"
	local operation=$2
	shift 2
	_GIT_PKGBUILD_STATE_ROOT="$TEST_ROOT/state"
	_PKGBUILD_USER=$(id -un)
	_PKGBUILD_HOME="$TEST_ROOT/home"
	_pkgbuild_setup() { printf 'setup\n' >>"$TEST_ROOT/operations"; }
	pkg_install() {
		printf 'prerequisite %s\n' "$*" >>"$TEST_ROOT/operations"
		[[ $* != 'arch:aur/fixture-aur' ]] || touch "$TEST_ROOT/optional-installed"
	}
	chown() { :; }
	sudo() {
		shift 2
		"$@"
	}
	_pkgbuild_make() {
		local directory=$1
		shift
		(
			cd -- "$directory"
			env "$@" makepkg --nodeps --nocheck --nosign >/dev/null
		)
		printf 'native-transaction\n' >>"$TEST_ROOT/operations"
	}
	pacman() {
		[[ $* == '-Si -- fixture-native' ]] ||
			{ [[ $1 == -T && -e $TEST_ROOT/optional-installed ]]; }
	}
	pkg_native_is_installed() {
		[[ $1 == example-git || $1 == example-session-git ]] ||
			{ [[ -e $TEST_ROOT/optional-installed && ($1 == fixture-native || $1 == fixture-aur) ]]; }
	}
	pkg_native_remove() { printf 'remove %s\n' "$*" >>"$TEST_ROOT/operations"; }
	"source_$operation" "$@"
)

# Unselected/other-distro providers perform no preparation.
printf 'test\t%s\tarch:git-pkgbuild/example.test/upstream\n' \
	"$PROJECT_ROOT/modules/desktop/hyprland" >"$TEST_ROOT/plan"
DISTRO=fedora pkg_install_plan "$TEST_ROOT/plan"
[[ ! -e $TEST_ROOT/operations ]]
printf 'test\t%s\tarch:git-pkgbuild/example.test/upstream\n' \
	"$PROJECT_ROOT/modules/desktop/hyprland" >"$TEST_ROOT/plan"
pkg_install_plan "$TEST_ROOT/plan"
[[ $(cat "$TEST_ROOT/operations") == $'setup\nprerequisite git\nsetup\nprerequisite git\nnative-transaction\nprerequisite fixture-native\nprerequisite arch:aur/fixture-aur' ]]
touch "$TEST_ROOT/optional-installed"
package=$(find "$PKGDEST" -name 'example-git-*.pkg.tar.*' -print -quit)
[[ $(bsdtar -xOf "$package" usr/share/example/payload) == 'working tree' ]]
[[ $(cat "$TEST_ROOT/upstream/payload") == 'working tree' ]]
[[ $(git -C "$TEST_ROOT/upstream" rev-list --count HEAD) == 1 ]]
_pkg_plugin_call "$provider" is_installed example.test/upstream
rm "$TEST_ROOT/optional-installed"
if _pkg_plugin_call "$provider" is_installed example.test/upstream; then
	printf 'Missing optional dependencies were reported installed\n' >&2
	exit 1
fi
touch "$TEST_ROOT/optional-installed"
# An upstream commit advances pkgver through the same source installation path.
printf 'updated\n' >"$TEST_ROOT/upstream/payload"
git -C "$TEST_ROOT/upstream" add payload
git -C "$TEST_ROOT/upstream" -c commit.gpgsign=false -c user.name=Test -c user.email=test@example.test commit -qm update
# Exercise the production remote-clone path with a local fixture transport.
# No explicit checkout override participates in this build.
GIT_PKGBUILD_LOCAL_DIR='' GIT_CONFIG_COUNT=1 \
	GIT_CONFIG_KEY_0="url.file://$TEST_ROOT/upstream.insteadOf" \
	GIT_CONFIG_VALUE_0=https://example.test/upstream.git \
	pkg_install_plan "$TEST_ROOT/plan"
[[ -f $PKGDEST/example-git-r2.g$(git -C "$TEST_ROOT/upstream" rev-parse --short HEAD)-1-any.pkg.tar.zst ]]
_pkg_plugin_call "$provider" remove example.test/upstream
rg -q '^remove example-git example-session-git$' "$TEST_ROOT/operations"
if _pkg_plugin_call "$provider" is_installed example.test/upstream; then exit 1; fi
# Validate malformed refs without performing host preparation.
if _pkg_plugin_call "$provider" install '../escape'; then exit 1; fi
printf 'external Git PKGBUILD source: ok\n'
