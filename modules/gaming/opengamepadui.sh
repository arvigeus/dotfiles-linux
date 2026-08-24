#!/usr/bin/env bash

packages=(
	arch:aur/opengamepadui-bin
	fedora:terra/opengamepadui
)

pkg_install "${packages[@]}"
