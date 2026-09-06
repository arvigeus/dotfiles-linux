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
