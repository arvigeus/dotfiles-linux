%global tag v3.7.3

Name:           appmanager
Version:        3.7.3
Release:        1%{?dist}
Summary:        AppImage installer and management application
License:        GPL-3.0-or-later
URL:            https://github.com/kem-a/AppManager
Source0:        %{url}/archive/refs/tags/%{tag}.tar.gz
ExclusiveArch:  x86_64

BuildRequires:  gcc
BuildRequires:  gettext
BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  vala
BuildRequires:  glib2-devel
BuildRequires:  gnutls-devel
BuildRequires:  gtk4-devel
BuildRequires:  json-glib-devel
BuildRequires:  libadwaita-devel
BuildRequires:  libgee-devel
BuildRequires:  libsecret-devel
BuildRequires:  libsoup3-devel
Requires:       ca-certificates
Requires:       squashfs-tools
%global debug_package %{nil}

%description
A GTK application for installing, organizing, launching, and updating
AppImages. DwarFS and zsync helpers are not bundled in this Fedora build.

%prep
%autosetup -n AppManager-%{version}

%build
%meson \
    -Dbundle_dwarfs=false \
    -Dbundle_zsync=false \
    -Dbundle_unsquashfs=false
%meson_build

%install
%meson_install
rm -f %{buildroot}%{_datadir}/glib-2.0/schemas/gschemas.compiled
%find_lang app-manager

%files -f app-manager.lang
%license LICENSE
%doc README.md
%{_bindir}/app-manager
%{_datadir}/applications/com.github.AppManager.desktop
%{_datadir}/metainfo/com.github.AppManager.metainfo.xml
%{_datadir}/glib-2.0/schemas/com.github.AppManager.gschema.xml
%{_datadir}/icons/hicolor/scalable/apps/com.github.AppManager.svg

%changelog
* Tue Aug 25 2026 system project contributors <root@localhost> - 3.7.3-1
- Build AppManager without unavailable Fedora DwarFS and zsync helpers
