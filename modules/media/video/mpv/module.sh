#!/usr/bin/env bash
## mpv media player with shaders and plugins
## https://mpv.io/
set -Eeuo pipefail

source "$SETUP_ROOT/lib/module.sh"
source "$SETUP_ROOT/lib/repo-health.sh"

module_healthcheck() {
	repo_health https://github.com/tomasklaen/uosc -m 12
	repo_health https://github.com/po5/thumbfast -m 36
}

# Configuration
SHADERS_DIR="/usr/share/mpv-shim-default-shaders/shaders"
PACK_JSON="/usr/share/mpv-shim-default-shaders/pack-next.json"
MPV_CONF_DIR="/etc/mpv"

# shellcheck disable=SC2034 # consumed by module_entrypoint through a nameref
packages=(
	mpv jq
	arch:chaotic-aur/mpv-uosc
	arch:mpv-shim-default-shaders
	arch:chaotic-aur/mpv-thumbfast-git
	arch:pkgbuild/mpv-sosc
	fedora:rpmspec/mpv-uosc
	fedora:rpmspec/system-mpv-extras
)

module_apply() {
	# Package-owned shader and plugin payloads provide pack-next.json before this
	# configuration phase begins.
	[[ -f $PACK_JSON ]] || {
		printf 'MPV extras package did not install %s\n' "$PACK_JSON" >&2
		return 1
	}

	# Generate mpv profile sections from upstream pack-next.json
	file_append "${MPV_CONF_DIR}/mpv.conf" <<'HEADER'
# Auto-generated from https://github.com/iwalton3/default-shader-pack/blob/master/pack-next.json
HEADER
	jq -r --arg sd "${SHADERS_DIR}" '
    .["setting-groups"] as $g |
    .profiles | to_entries[] |
    .key as $n | .value as $p |
    ($p["setting-groups"] // []) as $sgs |
    ([($sgs[] | $g[.].shaders // [] | .[])] + ($p.shaders // [])) as $shaders |
    [($sgs[] | $g[.].settings // [] | .[])] as $settings |
    "[\($n)]",
    ($settings[] |
        "\(.[0] | gsub("_"; "-"))=\(
            if .[1] == true then "yes"
            elif .[1] == false then "no"
            else .[1] | tostring
            end
        )"
    ),
    ($shaders | to_entries[] |
        if .key == 0 then "glsl-shaders=\($sd)/\(.value)"
        else "glsl-shaders-append=\($sd)/\(.value)"
        end
    ),
    ""
' "${PACK_JSON}" | file_append "${MPV_CONF_DIR}/mpv.conf"

	# Convenience aliases for long profile names
	file_append "${MPV_CONF_DIR}/mpv.conf" <<'EOF'
[fsr]
profile=AMD FidelityFX Super Resolution

[cas]
profile=AMD FidelityFX Contrast Adaptive Sharpening

EOF

	# Custom combo profile (not in upstream shader pack)
	file_append "${MPV_CONF_DIR}/mpv.conf" <<EOF
[fsr-cas]
glsl-shaders=${SHADERS_DIR}/FSR.glsl
glsl-shaders-append=${SHADERS_DIR}/CAS-scaled.glsl
EOF

	# Generate input.conf menu entries for profiles without manual keybindings
	BOUND_PROFILES="fsr-cas generic-high nnedi-very-high anime4k-high-a anime4k-high-b anime4k-high-c anime4k-high-aa anime4k-high-bb anime4k-high-ca"
	jq -r --arg skip "$BOUND_PROFILES" '
    ($skip | split(" ")) as $skip_list |
    .profiles | to_entries[] |
    select(.key as $k | $skip_list | index($k) | not) |
    "# apply-profile \"\(.key)\"; show-text \"Profile: \(.value.displayname // .key)\" #! Profiles > \(.value.displayname // .key)"
' "${PACK_JSON}" | file_append "${MPV_CONF_DIR}/input.conf"
}

module_entrypoint "$@"
