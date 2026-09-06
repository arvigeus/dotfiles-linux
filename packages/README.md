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
