---
type: Guide
title: Testing before publishing with coprctl
description: Use coprctl to run this same image locally before a Copr build, so a spec is tested before it reaches the build queue.
status: stable
tags: [rpm, copr]
---

# Testing before publishing with coprctl

rpmbuilder builds packages; Copr is one of the places they get published. [coprctl](https://coprctl.lab.abn.is/)
is a command-line and agent interface for Fedora Copr ([source on GitHub](https://github.com/abn/coprctl)),
and its local build backend is this project: it runs the same `quay.io/abn/rpmbuilder` image, so a spec
can be tested on the machine that wrote it before it is submitted.

Two coprctl commands do local work:

| Command | What it builds |
|---|---|
| `coprctl build srpm` | a source RPM from a spec |
| `coprctl try` | the full preflight: the SRPM, then a rebuild in a clean buildroot |

## How coprctl uses rpmbuilder

`coprctl --runtime container` runs the rpmbuilder image through podman or docker, following the same
conventions this documentation describes:

| Convention | coprctl's use |
|---|---|
| `/sources` | the spec directory is mounted here |
| `/output` | overridden to `/sources/.rpmbuild`, so artifacts land in the spec directory rather than at the image default |
| `BuildRequires` resolution | `dnf builddep` inside the image, the same as a [spec build](spec-builds.md) |
| Remote sources | fetched by `spectool`, so a `Source0:` URL needs no vendoring |
| SRPM first | `rpmbuild -bs`, then `rpmbuild -ba` for a preflight |

The Copr chroot name selects the image tag, so `fedora-44-x86_64` builds with
`rpmbuilder:fedora-44`. A chroot with no corresponding image is reported as uncovered rather than
silently skipped.

`--runtime` also accepts `mock` (a local clean buildroot that closely mirrors Copr's) and `native`
(`spectool` plus `rpmbuild` on the host, with no clean buildroot). The default, `auto`, prefers the
container when a container runtime is available, then mock, then native.

## Why preflight locally

Copr builds one chroot per target, in a queue, on remote infrastructure. A spec that fails on a
missing `BuildRequires`, a bad `Source` URL, or a `%files` mistake fails once per chroot, and the
evidence is in a remote log. Running the same image locally turns most of those into a failure you
see in seconds, with the build tree still on your machine.

It is also the cheapest way to check an architecture you do not run: the same image drives a
different target through `ARCH`, and the published tags are multi-architecture, so the preflight
matches the target rather than the host.

```bash
# a fast spec check, source RPM only
coprctl build srpm ./rpm --chroot fedora-44-x86_64

# the full preflight, mirroring what Copr will do
coprctl try ./rpm --chroot fedora-rawhide-x86_64

# force the container backend when the host also has mock
coprctl try ./rpm --chroot epel-9-x86_64 --runtime container
```

## Why one image for both sides

A build that passes locally and fails on Copr usually means the two environments differ. Because
coprctl's container backend is this image, the local buildroot is the one the documentation covers,
not a third variant to reason about: the same entrypoint, the same `BuildRequires` resolution, and
the same remote source fetching.

## What this does not replace

- The Copr build is authoritative. It uses Copr's own chroot, and signing and repository generation
  happen there. The preflight is a way to arrive at that build already correct, not a substitute for
  it.
- `coprctl --runtime native` is not a clean buildroot. Use `container` or `mock` when the point is
  dependency isolation.

## Next

- [Building from a spec file](spec-builds.md) for the path coprctl drives.
- [Enabling COPR and custom repositories](repositories.md) when a build dependency lives in a COPR project.
- [GitHub Actions integration](github-actions.md) if the build should run in CI rather than on a workstation.
