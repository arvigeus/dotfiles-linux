# Distribution and repository backends

Each supported distribution has one native backend:

```text
arch/distro.sh
fedora/distro.sh
```

A backend implements the `distro_*` lifecycle functions and these native package
operations:

```bash
pkg_native_install package...
pkg_native_is_installed package
pkg_native_remove package...
```

Repository plugins live in one of two locations:

```text
<distro>/repos/<repository>.sh  # distribution-specific, highest priority
common/repos/<repository>.sh    # shared fallback
```

There are no repository aliases, placeholders, or symlinks. If both locations
contain a plugin with the same name, the current distribution's plugin wins. If
neither exists, the package operation fails with an unknown-repository error.

A repository plugin implements:

```bash
repo_install package...
repo_is_installed package
```

It may additionally expose `repo_enable` for internal use. Repository setup
must be idempotent. A plugin can enable another repository with
`pkg_repo_enable`; FlatPark uses this to enable Flathub for runtimes. A plugin
may also install a dependency through the public package interface—for example,
the Arch `aur` plugin installs `chaotic-aur/paru`—instead of duplicating another
repository's setup. The
package dispatcher groups packages by repository, so `repo_install` receives
all matching packages in a single call. Repository removal is intentionally not
part of the declarative clean-root build model.

Modules select packages with:

```text
name                    current distro's native package
<distro>:<name>         native package selected only for that distro
<repo>/<name>           repository package on every distro that provides it
<distro>:<repo>/<name>  repository package selected only for that distro
```

Use distro scope for a distro-specific repository. For example,
`arch:aur/example` is ignored on Fedora, while unscoped `aur/example` is an
error there. Scope may also select a shared fallback only on one distro, as in
`fedora:cargo/just-lsp`. Shared repositories such as Flathub normally remain
unscoped.
