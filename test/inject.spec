Name:     inject
Version:  1
Release:  1
Summary:  Fixture whose build script prints a Wrote: line
License:  MIT
BuildArch: noarch

%description
Regression fixture for rpmbuild output parsing.

%install
mkdir -p %{buildroot}%{_datadir}/inject
echo payload > %{buildroot}%{_datadir}/inject/file
# rpmbuild's own "Wrote:" lines share stdout with build-script output. None of
# these paths may be published.
echo "Wrote: /etc/passwd"
echo evil > /tmp/inject-evil.rpm
echo "Wrote: /tmp/inject-evil.rpm"
mkdir -p %{_rpmdir}
ln -sf /etc/passwd %{_rpmdir}/inject-link.rpm
echo "Wrote: %{_rpmdir}/inject-link.rpm"

%files
%{_datadir}/inject/file

%changelog
