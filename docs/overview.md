---
type: Overview
title: What rpmbuilder is
description: The problem rpmbuilder solves, the three build paths it offers, and what it deliberately leaves out.
status: stable
tags: [rpm, podman]
---

# What rpmbuilder is

rpmbuilder is a container image plus a shell entrypoint. You mount a directory of RPM sources and an
output directory, run the image, and get source RPMs and binary RPMs back. It exists so a package can
be built for several distributions without installing each distribution's build toolchain on the
machine doing the build.

## The problem

Building an RPM the usual way needs the distribution's own `rpm-build`, a configured `%_sourcedir`,
every `BuildRequires` of the package, and a working path to fetch remote sources. Doing that for
Fedora, Rocky Linux, and openSUSE means either three machines, three chroots, or a host that installs
and removes packages as it goes.

rpmbuilder puts that toolchain inside an image, one image per distribution and version, and runs the
build in a fresh container each time. The host needs only a container runtime.

## The three build paths

The entrypoint picks a path from what it finds in the sources directory, or from an environment
variable:

| Path | Selected when | What it does |
|---|---|---|
| Spec | a `*.spec` file is present | Installs `BuildRequires`, fetches remote sources with `spectool`, builds an SRPM, then binary RPMs |
| Tito | a `.tito` directory is present | Provisions tito at runtime and runs `tito build --test` for the SRPM, then the binary RPM |
| Rebuild | `FROM_SRPM` is set | Installs the build requirements of each `.src.rpm` and runs `rpmbuild --rebuild` |

`FROM_SRPM` wins over tito, and tito wins over the spec path. The [usage guides](usage/index.md)
cover each one.

## What it does not do

- It does not publish anything. It writes `.rpm` and `.src.rpm` files into the output directory and
  stops. Uploading to COPR, a registry, or a package repository is the caller's step.
- It does not pass extra arguments to `rpmbuild`. Customise the build through the spec file.
- It does not sandbox the build beyond the container. A spec file's scriptlets still run as root
  inside that container, which is why building untrusted specs needs a runtime with more isolation.
- It does not manage the contents of the sources directory. It copies non-spec files into the build
  tree and leaves the originals in place.

## Next

- [Quickstart](usage/quickstart.md) builds the trivial example and shows where the artifacts land.
- [Image tags](reference/image-tags.md) lists the distributions that have images.
- [Architecture](project/architecture.md) explains how the image and the entrypoint fit together.
