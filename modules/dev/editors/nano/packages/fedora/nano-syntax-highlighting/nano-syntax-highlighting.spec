%global tag 2026.08.01

Name:           nano-syntax-highlighting
Version:        2026.08.01
Release:        1%{?dist}
Summary:        Improved syntax-highlighting definitions for GNU nano
License:        GPL-3.0-or-later
URL:            https://github.com/galenguyer/nano-syntax-highlighting
Source0:        %{url}/archive/refs/tags/%{tag}.tar.gz
BuildArch:      noarch
Requires:       nano
%global debug_package %{nil}

%description
Community-maintained syntax-highlighting definitions for GNU nano.

%prep
%autosetup -n %{name}-%{tag}

%install
install -d %{buildroot}%{_datadir}/%{name}
install -pm0644 *.nanorc %{buildroot}%{_datadir}/%{name}/

%files
%license license
%{_datadir}/%{name}/

%changelog
* Fri Sep 04 2026 system project contributors <root@localhost> - 2026.08.01-1
- Package the pinned upstream syntax definitions
