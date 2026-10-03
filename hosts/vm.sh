#!/usr/bin/env bash
# Small integration host: real installer, desktop and browser/runtime paths,
# without laptop-specific policy or the full workstation application collection.
modules=(
	base
	hardware/audio
	hardware/network
	hardware/bluetooth
	desktop
	browsers/firefox
	dev/languages/python
	system/security/ssh/client
	system/security/sudo
)
