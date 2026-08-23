#!/usr/bin/env bash
## lsd — The next gen ls command
## https://github.com/lsd-rs/lsd
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/env.sh"

packages=(lsd)

pkg_install "${packages[@]}"

shell_set_alias lsd ls "lsd --almost-all --group-dirs first --header --blocks name,size,permission,date --permission octal --date relative"

# Options:
#       --tree                         Recurse into directories and present the result as a tree
#       --depth <NUM>                  Stop recursing into directories after reaching specified depth
#       --total-size                   Display the total size of directories
#   -t, --timesort                     Sort by time modified
#   -S, --sizesort                     Sort by size
#   -X, --extensionsort                Sort by file extension
#   -G, --gitsort                      Sort by git status
#   -v, --versionsort                  Natural sort of (version) numbers within text
#       --sort <TYPE>                  Sort by TYPE instead of name [possible values: size, time, version, extension, git, none]
#   -r, --reverse                      Reverse the order of the sort
#       --no-symlink                   Do not display symlink target
#   -I, --ignore-glob <PATTERN>        Do not display files/directories with names matching the glob pattern(s). More than one can be specified by repeating the argument
