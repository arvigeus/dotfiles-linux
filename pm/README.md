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
`pm/<source>.sh`. Distro-specific sources live at
`pm/<distro>/<source>.sh`. A source plugin implements:

```bash
pm_enable
pm_install name...
pm_is_installed name
pm_remove name...
```

`pm_enable` must be idempotent. `pm_install` is responsible for calling it.
Plugins are loaded only when a selected package declaration refers to them.

See [the design contract](../docs/design.md) for resolution rules and examples.
