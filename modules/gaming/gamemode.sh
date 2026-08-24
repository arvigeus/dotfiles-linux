#!/usr/bin/env bash

packages=(
	gamemode
	arch:lib32-gamemode
	fedora:gamemode.i686
)

pkg_install "${packages[@]}"
