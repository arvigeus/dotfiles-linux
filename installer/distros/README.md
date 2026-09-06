# Distribution lifecycle backends

`arch/backend.sh` and `fedora/backend.sh` implement native base installation,
initial OS configuration, UKI generation, and distro-specific finalization such
as Fedora SELinux labelling.

Fedora runtime helpers installed by its backend live beside that backend. They
are installer-owned templates, not package-source plugins.

These are installer backends, not general distro namespaces. They do not own
module package dispatch. Native package-manager operations and configuration
live in `sources/arch/pacman.sh` and `sources/fedora/dnf.sh`;
demand-driven package source plugins live under `sources/`. See
[the design contract](../../docs/design.md) for that boundary.
