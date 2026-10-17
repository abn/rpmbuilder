---
type: Guide
title: Building from a spec file
description: The default path, which resolves BuildRequires, fetches remote sources, and publishes every subpackage the spec defines.
status: stable
tags: [rpm, podman]
---

# Building from a spec file

This is the path taken when the sources directory holds one or more `*.spec` files and no `.tito`
directory. It needs no extra environment variables beyond the mounts from the
[quickstart](quickstart.md).

## Order of operations

For each spec file the entrypoint:

1. Copies the non-spec files from the sources directory into the build tree's `%{_sourcedir}`.
2. Enables the repositories requested for this run (see
   [Enabling COPR and custom repositories](repositories.md)).
3. Installs the spec's `BuildRequires`. On a `dnf` system this is `dnf builddep`; on `zypper` it
   reads them with `rpmspec -q --buildrequires` and installs them in a single transaction.
4. Fetches remote sources with `spectool --sourcedir --get-files`.
5. Builds the SRPM with `rpmbuild -bs`, which fails fast on a bad spec before the slow compile.
6. Unless `SRPM_ONLY` is set, builds the binary RPMs with `rpmbuild -ba`.
7. Installs every artifact whose filename begins with one of the spec's
   `%{name}-%{version}-%{release}` prefixes into the output directory.

Steps 3 and 4 run for every spec file before any build starts, so all build dependencies and all
remote sources are present before the first compile.

## Multiple spec files

Drop several `*.spec` files in the sources directory and each is built in turn. This is how a
package split into a `-base` spec and a `-devel` spec, or a set of related packages, is built in one
run. The artifacts of every spec land in the same output directory.

## Subpackages

A spec can define several packages from one build, for example `demo`, `demo-libs`, and `demo-devel`.
The entrypoint reads the full package list from the spec with
`rpm --specfile ... --queryformat '%{name}-%{version}-%{release}\n'` and matches each prefix against
the built SRPMs and binary RPMs, so every subpackage is published rather than only the main package.

## Remote and local sources

`spectool` downloads anything declared as a full URL:

```spec
Source0: https://ftp.gnu.org/gnu/hello/hello-%{version}.tar.gz
```

A source declared as a bare filename is expected to sit next to the spec in the sources directory.
The copy step moves it into `%{_sourcedir}` unchanged.

## What gets copied

Everything in the sources directory except `*.spec` files, the output directory, and the run's own
configuration inputs (`.copr*`, `.repos*`). Hidden files are not copied by the copy glob. The
copied files are then owned by the build user inside the container.

## Restricting to an SRPM

Set `SRPM_ONLY` to stop after step 5. The run produces the `.src.rpm` and skips the compile, which is
useful for a fast spec check or the first half of a
[strict two-stage build](two-stage-tito.md).

```bash
podman run --rm -it \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env SRPM_ONLY=1 \
  quay.io/abn/rpmbuilder:fedora-latest
```

## Next

- [Rebuilding from an SRPM](rebuild-from-srpm.md) compiles an existing `.src.rpm` in a clean container.
- [Building for another architecture](architectures.md) changes the target from the image default.
