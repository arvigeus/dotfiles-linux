%global tag 5.13.0

Name:           mpv-uosc
Version:        5.13.0
Release:        1%{?dist}
Summary:        Feature-rich minimalist proximity-based UI for mpv
License:        LGPL-2.1-or-later
URL:            https://github.com/tomasklaen/uosc
Source0:        %{url}/releases/download/%{tag}/uosc.zip
Source1:        %{url}/releases/download/%{tag}/uosc.conf
Source2:        %{url}/raw/%{tag}/LICENSE.LGPL
ExclusiveArch:  x86_64
Requires:       mpv
BuildRequires:  unzip
%global debug_package %{nil}

%description
uosc is a proximity-based mpv interface. This package uses the release bundle
resolved at rebuild time and retains only the Linux ziggy helper.

%prep
%setup -q -c -T
unzip -q %{SOURCE0}
cp %{SOURCE1} uosc.conf
cp %{SOURCE2} LICENSE.LGPL

%install
install -d %{buildroot}%{_datadir}/mpv/scripts/uosc
cp -a scripts/uosc/. %{buildroot}%{_datadir}/mpv/scripts/uosc/
find %{buildroot}%{_datadir}/mpv/scripts/uosc/bin -maxdepth 1 -type f \
    ! -name ziggy-linux -delete
chmod 0755 %{buildroot}%{_datadir}/mpv/scripts/uosc/bin/ziggy-linux
install -Dm0644 uosc.conf %{buildroot}%{_datadir}/mpv/script-opts/uosc.conf
install -Dm0644 fonts/uosc_icons.otf \
    %{buildroot}%{_datadir}/mpv/fonts/uosc_icons.otf
install -Dm0644 fonts/uosc_textures.ttf \
    %{buildroot}%{_datadir}/mpv/fonts/uosc_textures.ttf

%files
%license LICENSE.LGPL
%{_datadir}/mpv/scripts/uosc/
%{_datadir}/mpv/script-opts/uosc.conf
%{_datadir}/mpv/fonts/uosc_icons.otf
%{_datadir}/mpv/fonts/uosc_textures.ttf

%changelog
* Tue Aug 25 2026 system project contributors <root@localhost> - 5.13.0-1
- Package the pinned upstream release bundle
