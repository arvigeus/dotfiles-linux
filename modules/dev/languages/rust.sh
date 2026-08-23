#!/usr/bin/env bash
## Rust toolchain
## https://rust-lang.org
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"

packages=(
	rust
	lldb
	fedora:cargo # dependency of rust for arch
)

pkg_install "${packages[@]}"
