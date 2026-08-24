#!/usr/bin/env bash

packages=(
	arch:chaotic-aur/gamescope-session-git
	arch:chaotic-aur/gamescope-session-steam-git
	arch:aur/gamescope-session-ogui-steam-git

	fedora:terra/gamescope-session
	fedora:terra/gamescope-session-steam
	fedora:terra/gamescope-session-ogui-steam
)

pkg_install "${packages[@]}"

# The session package ships Arch-only update and SDDM helpers at fixed Steam
# paths. Keep canonical project copies outside package-owned /usr/bin, then
# restore the compatibility links after relevant package transactions and at
# boot. An in-place update touches only the active A/B slot; the clean rebuild
# workflow remains separately available.
install -Dm755 "$MODULE_DIR/steamos-update" \
	/usr/local/libexec/dotfiles/steamos-update

install -Dm755 "$MODULE_DIR/steamos-restart-display-manager" \
	/usr/local/libexec/dotfiles/steamos-restart-display-manager

install -Dm755 "$MODULE_DIR/restore-gaming-session-overrides" \
	/usr/local/libexec/dotfiles/restore-gaming-session-overrides

/usr/local/libexec/dotfiles/restore-gaming-session-overrides

file_write /etc/tmpfiles.d/dotfiles-gaming-session.conf <<'EOF'
L+ /usr/bin/steamos-update - - - - /usr/local/libexec/dotfiles/steamos-update
L+ /usr/bin/steamos-polkit-helpers/steamos-restart-sddm - - - - /usr/local/libexec/dotfiles/steamos-restart-display-manager
EOF

if [[ $DISTRO == arch ]]; then
	file_write /etc/pacman.d/hooks/96-dotfiles-gaming-session.hook <<'EOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/bin/steamos-update
Target = usr/bin/steamos-polkit-helpers/steamos-restart-sddm

[Action]
Description = Restoring dotfiles gaming-session compatibility helpers...
When = PostTransaction
Exec = /usr/local/libexec/dotfiles/restore-gaming-session-overrides
EOF
fi
