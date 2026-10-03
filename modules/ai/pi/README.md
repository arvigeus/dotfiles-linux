# Pi system updates

## Enable

From the repository root:

```sh
pi install ./modules/ai/pi
# In an existing Pi session: /reload
```

Or try `pi -e ./modules/ai/pi/plugins/system-update/index.ts`.
Bootstrap/rebuild copies the extension into `~/.pi/agent/extensions/system-update/`.
Choose the copied extension **or** the local package, not both. Existing Pi
settings are preserved. The `ai` aggregate still selects this module as `pi`.

Requires Python 3, current Pi (`@earendil-works` API; tested against 0.82.1),
and `pacman-contrib` on Arch or DNF repoquery support on Fedora. The module
already declares those dependencies. Keep a web-search extension enabled for
initial changelog discovery; Pi has no built-in web search. Without search,
coverage remains unknown, never invented or silently approved.

## One command

```text
/system:update           check → review new evidence if needed → offer updates → safe housekeeping
/system:update check     check/review without offering apply
/system:update status    show every cached candidate, decision and post-update instruction
/system:update review    reconsider unresolved decisions
/system:update apply     offer the current reviewed plan without another check/model turn
/system:update cleanup   conservative housekeeping and list anything needing manual attention
```

`/system-update` remains an alias. `audit` remains a read-only diagnostic option.
No startup jobs, scheduled upgrades, unconditional model calls or auto-confirm.
The default command continues to an interactive confirmation after AI review;
if a question still needs your answer, it waits. You can decline at any point.
Print/JSON/RPC modes cannot apply updates.

### What is updated

- **Arch:** detected from `/etc/os-release`; `checkupdates` refreshes a separate
  database, never live `pacman -Sy`. Apply is a full `sudo pacman -Syu`.
- **Fedora:** DNF4/5 repoquery discovers candidates and fetches RPM changelogs.
  Apply is `sudo dnf upgrade --refresh`. Multilib/kernel version identities
  remain distinct.
- **npm:** writable global prefix only; `npm outdated --global --json --long`
  supplies installed/target versions and search hints. No automatic sudo npm.
  Linked/non-registry outdated entries cause the entire npm update to be
  skipped, because a blanket global update could modify those unreviewed entries.
- **Flatpak:** default user and system installations, including runtimes,
  extensions and architectures. Ref, origin and installed/target commit IDs are
  retained, even when the displayed version does not change.

Native support is explicitly **Arch and Fedora**, not every derivative or
Linux distribution. Named Flatpak installations are reported as outside scope.

### Topgrade integration

If `topgrade` is already installed, it handles the discovered npm (`node`) and
Flatpak steps. Otherwise the same managers are invoked directly. No new AUR,
COPR or other repository is enabled to install Topgrade automatically.

Topgrade's dry-run is a **command preview, not a package/version inventory**.
Read-only manager adapters provide the actual candidates; the preview is saved
with the plan. Execution uses a fresh isolated config and an explicit step
allowlist. Your `topgrade.toml`, `topgrade.d`, custom hooks, native system step,
self-update, firmware steps and cleanup settings are **not** loaded. This avoids
updating the native system twice or running unreviewed hooks/removal/tuning.

AUR/source builds, pipx, other Topgrade steps, local recipes, firmware flashing
and Fedora release upgrades are **not integrated**. They are not described as
reviewed or silently run. Adding another manager requires a read-only inventory
adapter and matching execution scope; running unrestricted Topgrade would not
provide the changelog coverage promised by this workflow.

## News and changelog caching

Arch's official RSS feed is checked on every scan and before apply. Only unread
or revised entries fetch full articles. Initial use reviews all entries still
in the feed—no silently acknowledged baseline. Resolved articles remain read
across routine package updates; unresolved actions stay visible even after an
article ages out. Feed changes reopen review. Explicit `forget-news` resets a
read marker (omit `key` to reset all), then run check again.

This intentionally uses read acknowledgements, not continuous monitoring of old
articles or configuration changes. Reconsider a resolved advisory when making
related configuration/package changes. The finite RSS feed cannot prove
historical coverage: consult the [news archive](https://archlinux.org/news/) for
an old/long-neglected installation. News transport/XML failures stop the check.

Changelog discovery is lazy, per ecosystem/repository/package. Upstream and
native distro sources are tracked separately; Fedora distro notes come from
RPM metadata. Homepages and packaging/Flatpak commit logs are search hints, not
automatically changelogs. Several URLs can cover an installed-to-target range.
URL records default to version-scoped; a verified comprehensive changelog can
use `scope=rolling`. Later version ranges otherwise require new discovery.

An empty URL list means **searched and confirmed absent**, with provenance.
Absence is cached across versions until `forget-source`; transport failures,
bot challenges, lack of search access and incomplete coverage are not absence.
Known absence yields a deterministic **unavailable** warning without AI, not a
safe approval. Empty/failed fetches also stay visible without recurring model
calls; a repaired source/new usable document reopens review.

AI only searches/interprets new evidence or explicitly revisits a decision.
It can inspect a paginated installed inventory (including packages not upgrading)
and read configuration when needed. Evidence is untrusted data, never executable
instructions. Ready approval requires nonempty evidence, exact hashes and
receipt of **every page of every document**. These checks cannot prove the
model understood the text; version coverage and applicability still need judgment.
Reviews include required actions; `follow_up` preserves post-update/reboot
instructions even on ready decisions. Cached risks are rendered without AI.

Eight fetch workers, per-item checkpoints and a cancellable check UI avoid
serial downloads and repeated full-plan writes. Interrupted evidence collection
can resume through `evidence` requests; a new check deliberately refreshes
package evidence. Failed sources never become confirmed absence automatically.

## Decisions, apply and cleanup

Trivial reversible **unprivileged** fixes may be made after explanation and a
backup. Ambiguous, privileged or destructive migrations require guidance.
No automatic commands copied from changelogs, repository changes, conflict
bypasses, changed-config merges, package/kernel removal, reboot or power/GPU/
fan tuning. Repository `AGENTS.md` reintroduction gates remain authoritative.

Apply requires the Pi TUI, a plan younger than one hour and unchanged native
inventory, native/extra candidates, news feed, evidence and the displayed review
digest. A state lock prevents concurrent writers. Unresolved coverage requires
explicit risk acceptance; that does **not** turn unknown/unavailable into safe.
One Pi confirmation is followed by the managers' normal transaction proposals;
there is no extra typed `UPDATE` prompt. Unique attempt results distinguish
failure, completion and no changes; cancelled UI confirmation never runs upgrades.
A zero manager exit alone is not proof packages changed.

Candidates are **not a solved transaction**. Dependencies, replacements,
removals and repository changes can appear in the final manager proposal, with
an unavoidable gap after revalidation. Inspect it and decline unexplained
changes. No `-y`, `--noconfirm`, `--overwrite`, selective Arch upgrades,
`--skip-broken`, automatic retry or automatic rollback. When the candidate list
is empty the workflow does not run an upgrade transaction; this is not proof
that no replacement-only transition exists.

Safe housekeeping runs after successful commands, on a no-update default run,
or explicitly through `cleanup`. It removes only:

- unreferenced extension evidence/result files older than 30 days;
- redundant `.pacnew`/`.rpmnew` with matching contents **and metadata**, owned by
  the current user in a current-user-owned directory (never automatic sudo).

Changed/root-owned configs, dangling links, `.pacsave`/`.rpmsave` backups,
orphans, duplicate packages and old kernels are reported, **not deletion lists**.
An unprivileged `/etc` scan can miss inaccessible paths. Post-update audit records
failed services, native orphan/duplicate candidates and configuration leftovers.
Inspect native hook output before rebooting. No thermal, battery, GPU, suspend
or application behavior is claimed validated.

## State and validation

State remains at `${XDG_STATE_HOME:-~/.local/state}/pi-system-update/`:
`sources.json`, `reviews.json`, `news-read.json`, `plan.json`, resumable
`evidence-*.json`, per-attempt `result-*.json`, `transaction.json`,
`last-success.json`, `audit.json` and the separate Arch `checkupdates-db/`.
Writes are atomic/private and lock-guarded. Corrupt state fails visibly. Pi
branching does not rewind system state. `PI_SYSTEM_UPDATE_STATE` overrides the
location for tests; use only a private, trusted directory. Old URL/null source
records remain readable; existing reviews may need one new evidence pass.

The backend also works without AI, as an ordinary user:

```sh
python3 modules/ai/pi/plugins/system-update/backend.py --request '{"action":"check"}'
python3 modules/ai/pi/plugins/system-update/backend.py --request '{"action":"status","offset":0,"limit":50}'
bash tests/system-update.sh
```

Tests mock Arch/DNF4/DNF5/npm/Flatpak/Topgrade and use temporary state/home.
Runtime tests and strict TypeScript checking use an existing Pi installation,
otherwise report a skip. For local development, run `npm install --ignore-scripts`
in `modules/ai/pi`, then `npm run typecheck`; `tsconfig.json` also enables editor
checks. No real upgrades, cleanup of real configs, or physical
GA402RK validation are performed. Extensions have normal user permissions;
TTY/no-apply-tool gates are not a sandbox against arbitrary Bash/filesystem tools.
HTTPS/public-address validation is not a DNS-rebinding defense.

References: [Arch news](https://archlinux.org/feeds/news/),
[checkupdates](https://man.archlinux.org/man/checkupdates.8.en),
[DNF4](https://dnf.readthedocs.io/en/stable/command_ref.html),
[DNF5](https://dnf5.readthedocs.io/en/stable/commands/repoquery.8.html),
[npm outdated](https://docs.npmjs.com/cli/v11/commands/npm-outdated),
[Flatpak CLI](https://docs.flatpak.org/en/latest/flatpak-command-reference.html),
[Topgrade CLI/config](https://github.com/topgrade-rs/topgrade/blob/main/src/config.rs),
[Topgrade npm step](https://github.com/topgrade-rs/topgrade/blob/main/src/steps/node.rs),
[Topgrade Flatpak step](https://github.com/topgrade-rs/topgrade/blob/main/src/steps/os/linux.rs).
