# shellcheck shell=bash
# The VCS source is intentionally unpinned. makepkg fetches HEAD and computes
# pkgver from that checkout; recipe updates must never replace it with an archive.
printf 'Tracking %-42s latest repository HEAD (resolved by makepkg)\n' zephyrus-shell
