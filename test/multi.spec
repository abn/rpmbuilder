Name:     multi
Version:  1
Release:  1
Summary:  Fixture with multiple subpackages
License:  MIT
BuildArch: noarch

%description
Parent package for the multi-subpackage fixture.

%package -n multi-a
Summary:  Subpackage a

%description -n multi-a
Subpackage a.

%package -n multi-b
Summary:  Subpackage b

%description -n multi-b
Subpackage b.

%install
mkdir -p %{buildroot}%{_datadir}/multi
mkdir -p %{buildroot}%{_datadir}/multi-a
mkdir -p %{buildroot}%{_datadir}/multi-b
echo parent > %{buildroot}%{_datadir}/multi/parent
echo a > %{buildroot}%{_datadir}/multi-a/a
echo b > %{buildroot}%{_datadir}/multi-b/b

%files
%dir %{_datadir}/multi
%{_datadir}/multi/parent

%files -n multi-a
%dir %{_datadir}/multi-a
%{_datadir}/multi-a/a

%files -n multi-b
%dir %{_datadir}/multi-b
%{_datadir}/multi-b/b
