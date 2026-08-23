#!/usr/bin/env bash
## Fooyin — modular Qt music player
## https://www.fooyin.org/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/flatpak.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

repo_health https://github.com/fooyin/fooyin -m 12

## Alternatives considered:
## - https://mpz-player.org/
## - https://audacious-media-player.org/ (has a Qt interface option)
## - https://harmonoid.com/
packages=(
	flathub/org.fooyin.fooyin
)
pkg_install "${packages[@]}"
flatpak_alias fooyin org.fooyin.fooyin

file_write "$HOME/.var/app/org.fooyin.fooyin/config/fooyin/fooyin.conf" <<'EOF'
[General]
LogLevel=4

[Interface]
LockSplitterHandles=true
ShowTrayIcon=true

[Library]
ExcludeTypes=cue
MarkUnavailable=false
MarkUnavailableOnStartup=true
RestrictTypes=@Invalid()

[Player]
PlayMode=32
EOF

file_write "$HOME/.var/app/org.fooyin.fooyin/config/fooyin/layout.fyl" <<'EOF'
{
    "Name": "Default",
    "Version": 1,
    "Widgets": [
        {
            "SplitterVertical": {
                "State": "AAAA/wAAAAEAAAACAAAAIAAAAz0A/////wEAAAACAA==",
                "Widgets": [
                    {
                        "SplitterHorizontal": {
                            "State": "AAAA/wAAAAEAAAACAAAAkgAAANMA/////wEAAAABAA==",
                            "Widgets": [
                                { "SearchBar": { "AutoSearch": true, "SearchMode": 0 } },
                                {
                                    "SplitterHorizontal": {
                                        "State": "AAAA/wAAAAEAAAACAAACPwAAAHAA/////wEAAAABAA==",
                                        "Widgets": [
                                            { "SeekBar": { "ElapsedTotal": false, "ShowLabels": true } },
                                            { "PlayerControls": {} }
                                        ]
                                    }
                                }
                            ]
                        }
                    },
                    {
                        "Playlist": {
                            "Columns": "8:132|1|7:2|2|5",
                            "HeaderState": "AAAAZXjaY2BgYGVgYLBjYGCSA9JOQPyHgYHRhQEiDgKMQMwMxCxAzAQSt19Zcv7gdJ8/9revnFCVz7xiv1qmjvVEGIv9yQ9mildVLewvLPgsyMVvCNLI8B8IAO5gGCM=",
                            "ID": "ade60cf7961e4058bdcfb92691dec1be",
                            "Preset": 0,
                            "SingleMode": false
                        }
                    }
                ]
            }
        }
    ]
}
EOF
