# Local native package recipes

Locally maintained recipes live at `packages/<distro>/<name>/` and are consumed
only by an explicit distro-specific plugin.

Implemented today:

```text
arch:pkgbuild/example
  -> pm/arch/pkgbuild.sh
  -> packages/arch/example/PKGBUILD
```

A future Fedora recipe may use `packages/fedora/<name>/`, but its format and
plugin should be added only when there is a real package to support. This
directory stores recipes; repository enablement and installation logic belong
under `pm/`.
