# Local native package recipes

Locally maintained recipes live at `packages/<distro>/<name>/` and are consumed
only by an explicit distro-specific plugin. They are a fallback: prefer an
existing enabled repository or the AUR, using `arch:` and `fedora:` scopes when
availability differs.

Implemented routes:

```text
arch:pkgbuild/example
  -> pm/arch/pkgbuild.sh
  -> packages/arch/example/PKGBUILD

fedora:rpmspec/example
  -> pm/fedora/rpmspec.sh
  -> packages/fedora/example/example.spec
  -> packages/fedora/example/sources.sha256
```

Before modules run, bootstrap/rebuild copies this directory to `/run`, invokes
`packages/update.sh` for the selected distribution, and points both builders at
the resolved copy. Tagged projects follow GitHub's latest stable release;
projects without releases follow the default branch head. The updater computes
fresh SHA-256 checksums and fails the rebuild if resolution or verification is
not possible. The tracked files are fallback snapshots and are not modified.
Set `GITHUB_TOKEN` on bootstrap/rebuild to raise GitHub's API rate limit.

To refresh the tracked snapshots explicitly:

```bash
bash packages/update.sh packages arch
bash packages/update.sh packages fedora
```

Fedora source files are downloaded from the spec by `spectool` and must all be
listed in `sources.sha256`. Both builders run as dedicated unprivileged users;
Pacman or DNF installs the resulting native package and owns its payload. These
are in-candidate builds rather than clean-chroot builds, so builder tooling and
Fedora dependencies installed from `BuildRequires` remain in the candidate.

Recipes contain package acquisition, build dependencies, runtime dependencies,
and system payloads. Modules retain feature policy and user-profile staging.

This directory stores recipes; repository enablement and installation logic
belong under `pm/`.
