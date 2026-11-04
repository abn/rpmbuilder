Name:     outside
Version:  1
Release:  1
Summary:  Fixture whose rebuild output escapes the published build trees
License:  MIT
BuildArch: noarch

%description
Regression fixture for the empty-publish guard.

# write the rebuilt packages outside the trees the entrypoint publishes from
%define _rpmdir /tmp/outside-rpms

%install
mkdir -p %{buildroot}%{_datadir}/outside
echo payload > %{buildroot}%{_datadir}/outside/file

%files
%{_datadir}/outside/file

%changelog
