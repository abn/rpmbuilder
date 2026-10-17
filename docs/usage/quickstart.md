---
type: Guide
title: Quickstart
description: Mount your sources and an output directory, run the image, and collect the RPMs it produces.
status: stable
tags: [rpm, podman]
---

# Quickstart

By the end of this guide you will have built an SRPM and a binary RPM from a spec file, without
installing a build toolchain on the host.

## Prerequisites

| Thing | Why |
|---|---|
| podman or docker | runs the build |
| a `*.spec` file | rpmbuilder builds spec files, not build scripts |
| network access | fetches `BuildRequires`, and any remote `Source` URLs |

## Steps

1. Put the sources in one directory and create an output directory:

   ```bash
   mkdir -p "${PWD}/sources" "${PWD}/output"
   ```

   The spec file goes in `sources/`, next to any local tarballs it references. Remote sources
   declared as full URLs in `Source` or `Patch` lines are downloaded for you.

2. Run the image. Two bind mounts and one environment variable are the whole interface:

   ```bash
   podman run --rm -it \
     --volume "${PWD}/sources:/sources:z" \
     --volume "${PWD}/output:/output:z" \
     --env OUTPUT_USER="$(id -u)" \
     quay.io/abn/rpmbuilder:fedora-latest
   ```

   | Piece | Effect |
   |---|---|
   | `${PWD}/sources:/sources:z` | the directory the entrypoint reads specs and sources from |
   | `${PWD}/output:/output:z` | where finished RPMs and SRPMs are written |
   | `--env OUTPUT_USER=$(id -u)` | makes the artifacts owned by your host user instead of `root` |
   | `:z` | relabels the mount for SELinux; drop it on a host without SELinux |

   `OUTPUT_USER` matters on a bind mount. Without it the container writes the artifacts as `root`
   and you cannot remove them without `sudo`.

3. Collect the result:

   ```bash
   ls -l "${PWD}/output"
   ```

   Expect the binary RPM, any subpackages the spec defines, and one `.src.rpm` per spec file.

## What happened

The entrypoint copied the non-spec files into the build tree, installed the spec's `BuildRequires`,
fetched remote sources with `spectool`, built an SRPM with `rpmbuild -bs`, then built the binary RPMs
with `rpmbuild -ba`, and installed every artifact it recognised into `/output`. [Building from a spec
file](spec-builds.md) covers the details.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `permission denied` reading `/sources` | the mount needs `:z` on an SELinux host, or `--security-opt label=disable` |
| the output directory is empty | the build failed earlier; drop `--rm` and rerun with `--entrypoint bash` to inspect it |
| artifacts owned by `root` | `OUTPUT_USER` was not set to the host uid |

## Next

- [Building from a spec file](spec-builds.md) for the full spec path.
- [Enabling COPR and custom repositories](repositories.md) when a `BuildRequires` is not in the base distribution.
- [Debugging a build](debugging.md) when the container exits non-zero.
