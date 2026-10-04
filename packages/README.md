# Local native package recipes

Recipes are co-located with the leaf that owns them:

```text
modules/example/
├── module.sh
└── packages/
    ├── arch/example/
    │   ├── PKGBUILD
    │   └── update.sh
    └── fedora/example/
        ├── example.spec
        ├── sources.sha256
        └── update.sh
```

The package declarations remain `arch:pkgbuild/example` and
`fedora:rpmspec/example`. The builder source receives the declaring leaf's
package root; a recipe cannot accidentally resolve from another module.

Only selected leaves' recipe trees are copied to the candidate's temporary
`/run`. `packages/update.sh` invokes each recipe-local `update.sh` against that
copy, so tracked snapshots are not modified during provisioning. The updater
provides helpers for resolving GitHub releases/default-branch heads, validating
versions and commits, downloading with bounded retries, hashing sources, and
atomically replacing recipe fields.

`hash_url URL FILENAME` additionally places the verified download in the
ephemeral recipe copy. Use it for large sources so Makepkg or Spectool can reuse
the exact bytes that were hashed rather than downloading them twice. The cached
file is never written back into the repository.

Fedora sources downloaded by `spectool` must all be listed in
`sources.sha256`. PKGBUILDs and RPM specs build under dedicated unprivileged
accounts; Pacman or DNF installs the resulting native package.

Recipes are a fallback. Prefer an existing trusted repository or the AUR when
it already supplies the package. Source-provider behavior belongs in the
module-local `sources/` directory or the shared top-level `sources/` directory.

## Automatic refresh and stable sources

Both `bootstrap.sh` and `rebuild.sh` call `run_modules`, which runs
`_prepare_module_packages` before `_apply_package_plan`. All recipe-local
`update.sh` files for selected modules and the target distribution run before
any module packages are built or installed. No separate manual update command
is required. Missing updaters or failed resolution abort provisioning; the
tracked snapshots are not a fallback during a normal install/rebuild.

`release_resolve` uses GitHub's latest stable release and explicitly rejects
responses marked draft/prerelease or missing those flags.
`release_commit_resolve` resolves that release tag through the commits API, so
recipes using commit archives can select stable releases too. sosc (Arch and
Fedora) and Fedora's Wallhaven widget now use this path rather than default
branch HEAD. Repository/AUR packages follow their provider's published versions.

Upstream exceptions checked on 2026-10-02: thumbfast and the Plasma Overview
widget publish neither GitHub releases nor version tags. Their existing
checksummed default-branch snapshots remain automatic, but are not described
as stable releases. Zephyrus owns its PKGBUILD upstream and is consumed through the Hyprland
leaf's Git source provider, rather than a local recipe/update.sh. GravityMark resolves the vendor's current installer.
Recheck these exceptions when upstream starts publishing releases.

The orchestration test in `tests/package-recipes.sh` checks both distributions,
refresh-before-build ordering, preservation of tracked snapshots, and aborting
before package/application phases on updater failure.
