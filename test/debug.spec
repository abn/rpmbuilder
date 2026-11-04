Name:     debug
Version:  1
Release:  1
Summary:  Fixture that produces debuginfo and debugsource packages
License:  MIT
BuildRequires: gcc

%description
Regression fixture for auto-generated debug packages.

%debug_package

%build
cat > hello.c <<'C'
#include <stdio.h>

int main(void)
{
    puts("hello");
    return 0;
}
C
gcc -g -O0 hello.c -o hello

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 hello %{buildroot}%{_bindir}/hello

%files
%{_bindir}/hello

%changelog
