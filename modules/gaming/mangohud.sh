#!/usr/bin/env bash

packages=(
	mangohud
	arch:lib32-mangohud
	fedora:mangohud.i686
)

pkg_install "${packages[@]}"
