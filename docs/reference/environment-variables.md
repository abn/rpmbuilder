---
type: Reference
title: Environment variables
description: Every variable the entrypoint and the image read, with its default and its effect.
status: stable
tags: [reference, configuration]
---

# Environment variables

Pass these with `--env NAME=value` on `podman run` or `docker run`.

## Build inputs and outputs

| Variable | Default | Effect |
|---|---|---|
| `SOURCES` | `/sources` | Directory the entrypoint reads specs, sources, or SRPMs from. Also the first positional argument, if given. |
| `OUTPUT` | `/output`, or `${SOURCES}/.rpmbuild` when `SOURCES` is overridden | Directory the built artifacts are installed into. Created if absent. |
| `OUTPUT_USER` | the container `USER` | Owner and group applied to the artifacts. Set it to the host uid so a bind-mounted output directory stays writable by you. |
| `ARCH` | `uname -m` | Target RPM architecture: `x86_64`, `aarch64`, `noarch`, and so on. |

`OUTPUT` only falls back to `${SOURCES}/.rpmbuild` when the image's own default is not in play. The
published images set `OUTPUT=/output`, so the fallback applies to the entrypoint run outside an
image, or when you override `SOURCES` without also setting `OUTPUT`.

## Build behaviour

| Variable | Default | Effect |
|---|---|---|
| `SRPM_ONLY` | unset | Stop after the source package. Skips the binary RPM compile on the spec and tito paths. |
| `FROM_SRPM` | unset | Treat `SOURCES` as a directory of `.src.rpm` files and rebuild binary RPMs from them. Takes precedence over the tito and spec paths. |
| `RPM_LINT` | unset | Run `rpmlint --verbose --info` on each published artifact. A non-zero exit fails the run. |
| `COPR_REPOS` | unset | Space- or comma-separated COPR projects to enable before dependency resolution. |
| `REPOS` | unset | Space- or comma-separated custom repository URLs to enable. |
| `ADDITIONAL_REPOS` | unset | An alias for `REPOS`; both are merged. |

`SRPM_ONLY`, `FROM_SRPM`, `RPM_LINT`, and `DEBUG` are read for presence, not value. `SRPM_ONLY=0`
still means "only the SRPM", so unset a variable rather than setting it to a false-looking value.

## Diagnostics

| Variable | Default | Effect |
|---|---|---|
| `DEBUG` | unset | Turn on `set -x` in the entrypoint. The non-empty check means any value enables it. |
| `VERBOSE` | unset | An alias for `DEBUG`. |

## Image build arguments

These are read when the image is built, not when it runs, so they go on `podman build` or `make`
rather than `podman run`.

| Argument | Default | Effect |
|---|---|---|
| `BASE_IMAGE` | `fedora` | The distribution image the rpmbuilder image is layered on. |
| `EXTRA_PACKAGES` | empty | Additional packages installed into the image at build time. |

## Order of selection

The entrypoint chooses one path, in this order:

1. `FROM_SRPM` set: rebuild from the `.src.rpm` files in `SOURCES`.
2. Otherwise, `.tito` directory present in `SOURCES`: the tito path.
3. Otherwise: build every `*.spec` in `SOURCES`.

## Next

- [Source configuration files](source-config-files.md) for the file-based equivalents of the repository variables.
- [Debugging a build](../usage/debugging.md) for how the diagnostic variables are used.
