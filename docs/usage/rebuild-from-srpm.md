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
4. Captures rpmbuild's output and publishes the packages it reports on its `Wrote:` lines. A path
   must be a regular `.rpm` that resolves inside the configured source RPM and binary RPM build
   trees; paths printed by a build script, including `..` and symlink tricks, are ignored. If no
   package is publishable, the run fails instead of publishing only the SRPM.
5. Copies the input `.src.rpm` to the output directory too, unless that file is already there.

A single run handles a directory of several `.src.rpm` files.

> [!NOTE]
> Publishing rpmbuild's own report covers every package the rebuild produced, including subpackages
> whose name or `Version`/`Release` differs from the source package, and debuginfo/debugsource
> packages generated automatically during the build. The path check is a sanity check against
> accidental log confusion, not a sandbox: a spec runs arbitrary code as root and can write to
> `/output` directly.

## Relation to the original build

`rpmbuild --rebuild` compiles the SRPM's spec against its bundled tarball. The result is a binary
package built from exactly the sources the SRPM contains, which is what makes it useful as a
reproducibility check. It cannot detect a source file missing from the SRPM, since the SRPM is the
input.

## Failure modes

| Message | Cause |
|---|---|
| `FROM_SRPM is set but no .src.rpm files found` | the sources mount points at a directory without source packages |
| `rpmbuild failed for ...` | the SRPM is malformed, or its spec needs a macro or a build dependency that is not installed |
| `rpmbuild reported no packages` | the rebuild succeeded but no `Wrote:` line could be parsed, so nothing would have been published |
| `rpmbuild produced no publishable packages` | every reported path was rejected (not a `.rpm`, outside the build trees, a symlink, or missing) |
| `rpmbuild reported a missing file: ...` | rpmbuild named a path that does not exist; that path is skipped |
| `ignoring unexpected 'Wrote:' path: ...` | a path is not a `.rpm`, or resolves outside the build trees, or is a symlink; it is not published |

## Next

- [Debugging a build](debugging.md) when the rebuild fails partway through.
- [GitHub Actions integration](github-actions.md) to run a rebuild in CI.
