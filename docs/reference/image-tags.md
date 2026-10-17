---
type: Reference
title: Image tags
description: The published rpmbuilder images, their distribution and version, and the tag to use.
status: stable
tags: [reference, fedora, rocky, opensuse]
---

# Image tags

Images are published to [`quay.io/abn/rpmbuilder`](https://quay.io/repository/abn/rpmbuilder?tab=tags).
A tag is a multi-architecture manifest covering `amd64` and `arm64`, so the same reference works on
either host.

## Published tags

| Distribution | Version or stream | Tag |
|---|---|---|
| Fedora | latest stable | `quay.io/abn/rpmbuilder:fedora-latest` |
| Fedora | 44 | `quay.io/abn/rpmbuilder:fedora-44` |
| Fedora | 43 | `quay.io/abn/rpmbuilder:fedora-43` |
| Fedora | Rawhide | `quay.io/abn/rpmbuilder:fedora-rawhide` |
| Rocky Linux | 10 | `quay.io/abn/rpmbuilder:rockylinux-10` |
| Rocky Linux | 9 | `quay.io/abn/rpmbuilder:rockylinux-9` |
| Rocky Linux | latest | `quay.io/abn/rpmbuilder:rockylinux-latest` |
| openSUSE Leap | 15.6 | `quay.io/abn/rpmbuilder:opensuse-leap-15.6` |
| openSUSE Leap | latest | `quay.io/abn/rpmbuilder:opensuse-leap-latest` |
| openSUSE Tumbleweed | rolling | `quay.io/abn/rpmbuilder:opensuse-tumbleweed-latest` |

The `latest` suffix tracks the current stable release of that distribution, so `fedora-latest` and
`fedora-44` name the same Fedora release until Fedora 45 lands. Pin a numbered tag when the target
release matters.

## How a tag is built

An image is the base distribution with the rpmbuilder toolchain layered on top. The tag name is a
convention over the base image, not a property of it:

```bash
BASE_IMAGE=quay.io/rockylinux/rockylinux:9 \
TARGET_IMAGE=rpmbuilder:rockylinux-9 \
make build
```

The base image is passed as a build argument and the packaging toolchain, `rpm-build`, `rpmdevtools`,
`rpmlint`, and the distribution's package manager plugins, is installed during the build. The
distribution also decides how tito is obtained at runtime.

## Reproducibility

The tags move. `fedora-latest` is rebuilt on a schedule and on every merge to `main`, and a
distribution's own base image changes under it. For a build that must not shift, pin the digest:

```bash
podman image inspect quay.io/abn/rpmbuilder:fedora-44 --format '{{index .RepoDigests 0}}'
```

Then use `quay.io/abn/rpmbuilder@sha256:<digest>` in the workflow or script.

## Choosing a tag

| Situation | Tag |
|---|---|
| A quick local build | `fedora-latest` |
| A package distributed for one Fedora release | the matching `fedora-<version>` |
| A package that must also land on a stable Enterprise Linux | `rockylinux-9` or `rockylinux-10` |
| openSUSE Leap packaging | `opensuse-leap-<version>` |
| Testing against a moving distribution | `fedora-rawhide` |

## Next

- [Container layout](container-layout.md) for what is inside an image.
- [GitHub Actions integration](../usage/github-actions.md) for the `images` input that takes these suffixes.
