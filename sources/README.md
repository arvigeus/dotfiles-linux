# Package manager and source plugins

Native distro operations and manager configuration are implemented by
`arch/pacman.sh` and `fedora/dnf.sh`:

```bash
pkg_native_configure [root-prefix]
pkg_native_install package...
pkg_native_is_installed package
pkg_native_remove package...
```

The native files are selected from the detected `PACKAGE_MANAGER`; their
directory shape permits another manager to be added without putting its setup
in the distro lifecycle backend. Shared package sources live at
`sources/<source>.sh`. Distro-specific sources live at
`sources/<distro>/<source>.sh`. A source plugin implements:

```bash
source_prepare
source_install name...
source_is_installed name
source_remove name...
```

`source_prepare` must be idempotent. The plan executor prepares every referenced
source before the grouped install phase; `source_install` must also remain safe
when called by a source bootstrap path. Plugins are loaded only when a selected
package or explicit module `sources` declaration refers to them.

Resolution checks module-scoped, module-shared, global-scoped, then
global-shared providers. A distro prefix limits applicability even when the
resolved provider is shared. Keep one-consumer sources beside their module and
promote them here only when they become shared infrastructure.

See [the design contract](../docs/design.md) for resolution rules and examples.

## External Git PKGBUILDs

The Hyprland leaf owns `sources/arch/git-pkgbuild.sh`, a generic one-consumer
provider for `arch:git-pkgbuild/HOST/PATH`. It fetches HTTPS default-branch HEAD,
requires a root PKGBUILD, and installs **all split package outputs** with the
existing unprivileged native builder. It executes upstream recipes as the build
account, never as root. Generated SRCINFO records native package names for
installed-state and removal operations. Planning sources only the provider's
functions; it never clones, builds or reads upstream metadata.

Preparation installs generic Git/build prerequisites only. Every installation
fetches current metadata and payload together; matching VCS source URLs are
rewritten to the fetched checkout using standard Git configuration. Other
sources in that PKGBUILD retain their normal makepkg behavior. The provider does
not support arbitrary source fragments, subdirectory recipes or selecting only
some outputs; add such support only when a real consumer requires it.

For an explicit local source test on an existing Arch root:

```bash
sudo env GIT_PKGBUILD_LOCAL_DIR="$PWD/../zephyrus-shell" bash -c '
  export SETUP_ROOT="$1" DISTRO=arch PACKAGE_MANAGER=pacman PROJECT_ID=system
  source "$SETUP_ROOT/lib/module.sh"
  _pkg_plugin_call "$SETUP_ROOT/modules/desktop/hyprland/sources/arch/git-pkgbuild.sh" \
    install github.com/arvigeus/zephyrus-shell
' bash "$PWD"
```

This makes an isolated snapshot including non-ignored working-tree changes,
builds packages, and installs them through pacman. The original checkout is not
changed; dirty snapshots have a synthetic revision/hash. The override applies
to exactly one source transaction and must be unset for production builds.
During rebuild its path must be visible inside the candidate namespace; no home
checkout is implicitly discovered or mounted. Prefer upstream
`scripts/build-package.sh --syncdeps --install` for everyday local development.
