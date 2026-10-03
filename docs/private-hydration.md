# Optional private configuration after login

Public bootstrap and rebuild never clone `arvigeus/dotfiles-private`, read its
credentials, or require GitHub authentication. Its existing layout includes
legacy application scripts and SSH/GnuPG/rclone material; the private repository now provides a standalone `hydrate.sh` interface.
The public hook does not source legacy scripts or automatically import GPG keys.

After successfully booting and logging in, install/use `git` and `gh` as needed,
then authenticate as your login user:

```bash
gh auth login
./hydrate-private.sh
```

A deliberately supplied `GH_TOKEN` is also supported by `gh`; supply it through
your own secret manager/environment, never through a command saved in public
configuration. A GitHub account password is not supported. With existing SSH
credentials instead:

```bash
./hydrate-private.sh --ssh
```

The checkout is placed at
`$XDG_DATA_HOME/system-private/repository` (normally
`~/.local/share/system-private/repository`). The parent/tree directories are
0700 and regular files are 0600. The command refuses root execution, symlinks
in the checkout, and replacement of an existing checkout. It captures fetch
errors privately and reports only a generic error; it never prints file
contents, a token, or private Git history. Move an existing checkout aside
privately before fetching a newer snapshot.

## Applying private configuration

The private `hydrate.sh` runs as your login user with `umask 077`. It installs
an explicit SSH allowlist, rclone, Git identity, npm preferences, Chromium
environment, Kodi Flatpak environment and Zephyrus media credentials. It uses
standard application files, backs up differing destinations, rejects symlinks,
and changes no packages or system policy. GPG import requires the separate
private command `bash hydrate.sh --import-gpg`; this enables commit signing.

After committing that reviewed hook privately, a fresh fetch can explicitly
apply it:

```bash
./hydrate-private.sh --apply
```

If the already-fetched checkout has a reviewed hook, invoke it locally:

```bash
umask 077
bash "${XDG_DATA_HOME:-$HOME/.local/share}/system-private/repository/hydrate.sh"
```

`--apply` captures hook output in an owner-only `system-private/apply.log`,
which you should inspect locally without posting its contents. The public
installer cannot enforce arbitrary code inside a private hook; permission and
backup checks for final destination files belong to that reviewed private hook.
The private changes must be committed and published before a remote fetch can use them.

Private target configuration in the persistent home survives clean-root
rebuilds. Keep it outside `/etc/skel` and public skeleton defaults. System
credentials under `/etc` need a separately reviewed preservation mechanism;
they are not handled by this user-only hook.
