%global commit 030224751ad7114e695297c9f0822b668baee5f9

Name:           plasma6-applets-overview-widget
Version:        1.5
Release:        1%{?dist}
Summary:        Overview toggle widget for Plasma 6
License:        GPL-3.0-or-later
URL:            https://github.com/HimDek/Overview-Widget-for-Plasma
Source0:        %{url}/archive/%{commit}.tar.gz
BuildArch:      noarch
BuildRequires:  gzip
BuildRequires:  tar
Requires:       plasma-workspace

%description
A small Plasma 6 widget that toggles the desktop Overview effect.

%prep
%autosetup -n Overview-Widget-for-Plasma-%{commit}

%install
install -d %{buildroot}%{_datadir}/plasma/plasmoids/com.himdek.kde.plasma.overview
cp -a ./. %{buildroot}%{_datadir}/plasma/plasmoids/com.himdek.kde.plasma.overview/

%files
%license LICENSE.md
%{_datadir}/plasma/plasmoids/com.himdek.kde.plasma.overview/

%changelog
* Tue Aug 25 2026 system project contributors <root@localhost> - 1.5-1
- Package the pinned Plasma Overview widget
