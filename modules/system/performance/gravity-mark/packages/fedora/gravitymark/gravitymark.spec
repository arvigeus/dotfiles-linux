Name:           gravitymark
Version:        1.89
Release:        1%{?dist}
Summary:        Cross-platform GPU benchmark
License:        LicenseRef-Proprietary
URL:            https://gravitymark.tellusim.com/
Source0:        https://tellusim.com/download/GravityMark_%{version}.run
ExclusiveArch:  x86_64
%global debug_package %{nil}

%description
Tellusim GravityMark cross-platform GPU benchmark.

%prep
%setup -q -c -T

%install
install -Dm0755 %{SOURCE0} %{buildroot}/opt/gravity-mark/GravityMark.run
install -d %{buildroot}%{_bindir}
cat >%{buildroot}%{_bindir}/gravity-mark <<'EOF'
#!/usr/bin/env bash
exec /opt/gravity-mark/GravityMark.run "$@"
EOF
chmod 0755 %{buildroot}%{_bindir}/gravity-mark

%files
/opt/gravity-mark/GravityMark.run
%{_bindir}/gravity-mark

%changelog
* Fri Sep 04 2026 system project contributors <root@localhost> - 1.89-1
- Package the pinned upstream installer
