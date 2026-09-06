%global commit 174c29c27ba7eb62c3da75238f6f8f91e7415125

Name:           plasma6-applets-wallhaven-reborn
Version:        2.0.2
Release:        1%{?dist}
Summary:        Wallhaven wallpaper plug-in for Plasma 6
License:        GPL-3.0-only
URL:            https://github.com/Blacksuan19/plasma-wallpaper-wallhaven-reborn
Source0:        %{url}/archive/%{commit}.tar.gz
BuildArch:      noarch
BuildRequires:  gzip
BuildRequires:  tar
Requires:       plasma-workspace

%description
A Plasma 6 wallpaper plug-in that fetches wallpapers from wallhaven.cc.

%prep
%autosetup -n plasma-wallpaper-wallhaven-reborn-%{commit}

%install
install -d %{buildroot}%{_datadir}/plasma/wallpapers/com.plasma.wallpaper.wallhaven
cp -a package/. %{buildroot}%{_datadir}/plasma/wallpapers/com.plasma.wallpaper.wallhaven/

%files
%license LICENSE
%{_datadir}/plasma/wallpapers/com.plasma.wallpaper.wallhaven/

%changelog
* Tue Aug 25 2026 system project contributors <root@localhost> - 2.0.2-1
- Package the pinned Wallhaven wallpaper plug-in
