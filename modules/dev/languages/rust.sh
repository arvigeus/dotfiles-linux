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

# To use rustup instead of the distro Rust toolchain, remove the distro Rust
# packages, install rustup, then run:
#   rustup default stable
#   rustup component add clippy rustfmt rust-analyzer rust-src rust-lldb

module_entrypoint "$@"
