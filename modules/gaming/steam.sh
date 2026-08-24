#!/usr/bin/env bash

packages=(
	arch:steam
	fedora:rpmfusion/steam
)
pkg_install "${packages[@]}"
