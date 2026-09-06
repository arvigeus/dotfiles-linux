%global tag 144.0

Name:           arkenfox-user.js
Version:        144.0
Release:        1%{?dist}
Summary:        Arkenfox Firefox user.js privacy and security template
License:        MIT
URL:            https://github.com/arkenfox/user.js
Source0:        %{url}/archive/refs/tags/%{tag}.tar.gz
BuildArch:      noarch
%global debug_package %{nil}

%description
Privacy and security Firefox preferences maintained by the Arkenfox project.

%prep
%autosetup -n user.js-%{tag}

%install
install -Dm0644 user.js %{buildroot}%{_datadir}/arkenfox/user.js
install -Dm0644 LICENSE.txt %{buildroot}%{_licensedir}/%{name}/LICENSE.txt

%files
%license %{_licensedir}/%{name}/LICENSE.txt
%{_datadir}/arkenfox/user.js

%changelog
* Sat Sep 05 2026 system project contributors <root@localhost> - 144.0-1
- Package the pinned upstream Arkenfox template
