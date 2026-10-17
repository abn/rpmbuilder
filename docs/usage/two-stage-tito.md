---
type: Guide
title: Strict two-stage tito builds
description: Generate an SRPM with tito, then rebuild it in a clean container so only declared BuildRequires can be satisfied.
status: stable
tags: [rpm, tito, ci]
---

# Strict two-stage tito builds

Use this when the build must prove that the spec's `BuildRequires` are complete. It is the tito path
split in two, with the second half running in a container that has no tito and no Python build
helpers installed.

## The problem it solves

To run a tito build the entrypoint installs tito and its dependencies into the container. Those
packages can satisfy a `BuildRequires` that the spec forgot to declare. The build passes, the spec is
wrong, and the problem surfaces only on a clean machine or in a distribution build system.

Rebuilding from the SRPM removes the ambiguity: the second container installs only what the spec
declares, so an undeclared dependency fails the build where it should.

## Stage 1: generate the SRPM

```bash
podman run --rm -it \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env SRPM_ONLY=1 \
  quay.io/abn/rpmbuilder:fedora-latest
```

The output directory now holds the `.src.rpm` and nothing else.

## Stage 2: rebuild in a clean environment

Mount the output directory from stage 1 as the sources directory for stage 2:

```bash
podman run --rm -it \
  --volume "${PWD}/output:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env FROM_SRPM=1 \
  quay.io/abn/rpmbuilder:fedora-latest
```

Because `FROM_SRPM` is set, the tito path is not taken even though a `.tito` directory exists in the
project. The entrypoint installs the SRPM's requirements, rebuilds the binary RPMs with
`rpmbuild --rebuild`, and publishes them. [Rebuilding from an SRPM](rebuild-from-srpm.md) covers that
step on its own.

## In CI

The composite action runs one build per invocation, so the two stages are the action called twice
rather than a built-in mode. The reusable workflow wires this up behind `tito-two-stage`:

```yaml
jobs:
  rpm:
    uses: abn/rpmbuilder/.github/workflows/rpm-build.yml@main
    with:
      sources-path: .
      tito-two-stage: true
      images: '["fedora-latest", "rockylinux-9"]'
```

[GitHub Actions integration](github-actions.md) lists the other inputs.

## What it does not prove

Stage 2 rebuilds from the SRPM, so it cannot catch a missing file that should have been in the SRPM
in the first place: the SRPM is the input. Treat it as a check on `BuildRequires`, not on the
completeness of the tarball.

## Next

- [Rebuilding from an SRPM](rebuild-from-srpm.md) for the rebuild mechanics.
- [Enabling COPR and custom repositories](repositories.md) when the build dependencies live outside the base distribution.
