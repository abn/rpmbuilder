---
type: Guide
title: Building for another architecture
description: Target aarch64, noarch, or another architecture with the ARCH variable instead of a different image.
status: stable
tags: [rpm, configuration]
---

# Building for another architecture

`ARCH` sets the target architecture for the build. Leave it unset and the entrypoint uses the
container's own architecture, `uname -m`. Set it when the package is architecture independent, or
when you need a target other than the machine you are on.

```bash
podman run --rm -it \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env ARCH=aarch64 \
  quay.io/abn/rpmbuilder:fedora-latest
```

## How it is used

| Step | Flag |
|---|---|
| `dnf builddep` | `--forcearch "$ARCH"` |
| `yum-builddep` | `--target "$ARCH"` |
| `rpmbuild -bs`, `-ba`, `--rebuild` | `--target "$ARCH"` |

On a `zypper` system the dependency step installs the requirements the file records and passes no
architecture flag, so the container's own architecture decides there.

`ARCH=noarch` is handled specially on the dependency step: the architecture flag is dropped, because
`noarch` is not a real machine architecture to resolve packages for. The build itself still receives
`--target noarch`.

## Architectures and the images

The published tags are multi-architecture manifests for `amd64` and `arm64`, so the same reference
resolves to a native image on either kind of host. Check with:

```bash
podman image inspect quay.io/abn/rpmbuilder:fedora-latest --format '{{.Architecture}}'
```

For a target that neither the host nor the image runs natively, the build needs emulation or a cross
toolchain registered on the host. `ARCH` selects the target; it does not supply the compiler to reach
it.

## When to set noarch

Set `ARCH=noarch` for a package that ships no compiled objects, such as a set of shell scripts or a
`themes` package. That matches what the spec declares with `BuildArch: noarch`, and it keeps the
output filenames consistent with the package metadata.

## Next

- [Reference: environment variables](../reference/environment-variables.md) for the full variable list.
- [Reference: image tags](../reference/image-tags.md) for the distributions available.
