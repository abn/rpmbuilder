---
type: Guide
title: Rebuilding from an SRPM
description: Compile binary RPMs from existing .src.rpm files without the original sources or spec tree.
status: stable
tags: [rpm, podman]
---

# Rebuilding from an SRPM

Set `FROM_SRPM` when the sources directory holds `.src.rpm` files rather than a spec and its
sources. The entrypoint installs each SRPM's requirements and rebuilds it. This is the shape of the
second half of a [strict two-stage build](two-stage-tito.md), and it is also how you recompile a
source package someone handed you.

## Command

```bash
podman run --rm -it \
  --volume "${PWD}/srpms:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env FROM_SRPM=1 \
  quay.io/abn/rpmbuilder:fedora-latest
```

`FROM_SRPM` takes precedence over the tito and spec paths, so it works whether or not a `.tito`
directory happens to be present.

## What the entrypoint does

1. Reads every `*.src.rpm` in the sources directory. If there are none it stops with an error rather
   than exiting silently.
2. Installs the build requirements the SRPM records, with `dnf builddep` (or `yum-builddep`) on a
   `dnf` system and by reading `rpm -qp --requires` on a `zypper` system. The requirements come from
   the source package's own metadata, since an SRPM has no spec on disk to query directly.
3. Rebuilds with `rpmbuild --rebuild --target "$ARCH"`.
4. Derives the source package's `name-version-release` with
   `rpm -qp --queryformat '%{name}-%{version}-%{release}'`.
5. Publishes every `.rpm` in the source RPM and binary RPM build trees whose filename begins with
   that prefix.

A single run handles a directory of several `.src.rpm` files.

> [!NOTE]
> The prefix is the source package's own `name-version-release`, so it matches the main binary
> package. A subpackage whose filename inserts a segment, such as `demo-libs-1.0-1` against
> `demo-1.0-1`, does not begin with that prefix and is not copied to the output directory. The spec
> path publishes subpackages because it asks the spec for its full prefix list, and the tito path
> publishes every RPM tito produced.

## Relation to the original build

`rpmbuild --rebuild` compiles the SRPM's spec against its bundled tarball. The result is a binary
package built from exactly the sources the SRPM contains, which is what makes it useful as a
reproducibility check. It cannot detect a source file missing from the SRPM, since the SRPM is the
input.

## Failure modes

| Message | Cause |
|---|---|
| `FROM_SRPM is set but no .src.rpm files found` | the sources mount points at a directory without source packages |
| an `rpmbuild --rebuild` error | the SRPM is malformed, or its spec needs a macro or a build dependency that is not installed |

## Next

- [Debugging a build](debugging.md) when the rebuild fails partway through.
- [GitHub Actions integration](github-actions.md) to run a rebuild in CI.
