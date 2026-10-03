# Module contract

Hosts explicitly select modules:

```bash
# hosts/zephyrus.sh
modules=(base desktop gaming/steam dev)
```

A directory aggregate contains only ordered members:

```bash
# modules/gaming/module.sh
source "$SETUP_ROOT/lib/module.sh"
members=(meta steam mangohud gamescope launchers compat games)
module_entrypoint "$@"
```

A leaf declares packages and optional source activation, then keeps mutations
inside `module_apply`:

```bash
packages=(
    arch:multilib/steam
    fedora:rpmfusion/steam
)
sources=(arch:alhp)       # only for source activation without a package
requires=(base/utils)     # absolute module selectors; use sparingly

module_apply() { :; }
module_healthcheck() { :; }
module_entrypoint "$@"
```

`module_check` may return false for a hardware or distro condition. The same
check is evaluated during planning and immediately before application; a
changed result is fatal. Aggregate modules may declare only `members`.

`HOST_PROFILE` and `DESKTOP` are explicit installed-system inputs passed to
plan, apply and healthcheck processes. Desktop aggregates select their matching
implementation. Common media includes Kodi, which skips Hyprland through a
simple `module_check`; its `requires` edge owns the mpv dependency.

Each selected leaf is evaluated in an isolated Bash process. The phases are:

1. Expand explicit host selections, aggregates, and requirements.
2. Collect and validate every package/source declaration without mutation.
3. Prepare only referenced sources and install the deduplicated package plan.
4. Copy `files/` into the candidate root and call `module_apply` in plan order.
5. Run `module_healthcheck` only when `RUN_MODULE_HEALTHCHECKS=true`.

Module-local ownership follows these conventions:

```text
modules/dev/editors/vscode/
├── module.sh
├── files/                         # copied onto / after package installation
│   └── etc/example.conf
├── sources/
│   └── fedora/vscode.sh           # resolves fedora:vscode/code locally first
└── packages/
    └── fedora/example/            # resolves fedora:rpmspec/example
        ├── example.spec
        ├── sources.sha256
        └── update.sh
```

`files/` accepts regular files and directories; symlinks are rejected so an
overlay cannot escape its apparent destination. Two selected modules claiming
the same file path are a planning error.

Source lookup checks leaf-scoped, leaf-shared, global-scoped, then global-shared
providers. Thus `fedora:vscode/code` can use a Fedora provider owned by the
VS Code leaf, while `fedora:cargo/tool` can use the shared Cargo provider. A
source used by one leaf stays local; move it to the shared directory when a
second module needs it.

`module_apply` must be idempotent and non-interactive. It must not invoke
`pkg_install`, `pkg_repo_enable`, or another package manager. Online advisory
checks belong in `module_healthcheck`, not planning or application.

Use the ownership boundary consistently:

- upstream payloads installed under `/usr`, `/opt`, or another system payload
  location belong in a native package or an existing declared source;
- repository-owned static configuration and helper scripts belong in `files/`;
- generated, merged, or machine-dependent configuration belongs in
  `module_apply`;
- application profile state, such as a browser extension or Flatpak add-on,
  remains application configuration unless the application exposes a genuine
  system-package integration point.

Do not download an upstream archive in `module_apply` merely to copy files into
the system. Package ownership makes those files queryable, replaceable, and
removable on an ordinary mutable installation.
