%global shader_tag v3.0.0
%global thumbfast_commit 0f711de3138c9bd6718209d819ac54022c23ded2
%global sosc_commit 5491dbdd9286d3a6da4bb6976d914a7f82dc0727

Name:           system-mpv-extras
Version:        3.0.0.20260308
Release:        1%{?dist}
Summary:        MPV shaders and scripts selected by the system configuration
License:        GPL-2.0-only AND GPL-3.0-only AND LGPL-3.0-or-later AND MIT AND MPL-2.0 AND Unlicense
URL:            https://github.com/iwalton3/default-shader-pack
Source0:        %{url}/archive/refs/tags/%{shader_tag}.tar.gz
Source1:        https://github.com/po5/thumbfast/archive/%{thumbfast_commit}.tar.gz
Source2:        https://github.com/christoph-heinrich/sosc/archive/%{sosc_commit}.tar.gz
BuildArch:      noarch
BuildRequires:  tar
Requires:       mpv
%global debug_package %{nil}

%description
Pinned, checksummed MPV shader-pack, thumbfast, and seasonal OSC payloads.

%prep
%setup -q -c -T
tar -xzf %{SOURCE0}
tar -xzf %{SOURCE1}
tar -xzf %{SOURCE2}

%install
tag=%{shader_tag}
shader_dir=default-shader-pack-${tag#v}
thumbfast_dir=thumbfast-%{thumbfast_commit}
sosc_dir=sosc-%{sosc_commit}

install -d %{buildroot}%{_datadir}/mpv-shim-default-shaders
cp -a "$shader_dir/shaders" %{buildroot}%{_datadir}/mpv-shim-default-shaders/
install -pm0644 "$shader_dir"/pack*.json %{buildroot}%{_datadir}/mpv-shim-default-shaders/

install -Dm0644 "$thumbfast_dir/thumbfast.lua" \
    %{buildroot}%{_sysconfdir}/mpv/scripts/thumbfast.lua
install -Dm0644 "$thumbfast_dir/thumbfast.conf" \
    %{buildroot}%{_sysconfdir}/mpv/script-opts/thumbfast.conf
install -Dm0644 "$sosc_dir/osc.lua" \
    %{buildroot}%{_sysconfdir}/mpv/scripts/osc.lua

install -Dm0644 "$shader_dir/LICENSE.md" \
    %{buildroot}%{_licensedir}/%{name}/shader-pack.LICENSE.md
install -Dm0644 "$thumbfast_dir/LICENSE" \
    %{buildroot}%{_licensedir}/%{name}/thumbfast.LICENSE
install -Dm0644 "$sosc_dir/LICENSE" \
    %{buildroot}%{_licensedir}/%{name}/sosc.LICENSE

%files
%license %{_licensedir}/%{name}/
%{_datadir}/mpv-shim-default-shaders/
%{_sysconfdir}/mpv/scripts/thumbfast.lua
%{_sysconfdir}/mpv/scripts/osc.lua
%{_sysconfdir}/mpv/script-opts/thumbfast.conf

%changelog
* Fri Sep 04 2026 system project contributors <root@localhost> - 3.0.0.20260308-1
- Package pinned shader-pack, thumbfast, and sosc payloads
