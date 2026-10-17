---
type: Reference
title: Container layout
description: The mount points, in-container paths, and packages of a published rpmbuilder image.
status: stable
tags: [reference, podman]
---

# Container layout

## Mount points

| Path | Role |
|---|---|
| `/sources` | Input. Specs, sources, or `.src.rpm` files. The image declares it as a volume. |
| `/output` | Output. The built RPMs and SRPMs are installed here. The image declares it as a volume. |
| `/etc/pki/ca-trust/source/anchors` | Optional. CA certificates to add on a Red Hat derived image. |
| `/etc/pki/trust/anchors` | Optional. CA certificates to add on an openSUSE image. |

Both `/sources` and `/output` are declared as volumes, so running the image without a mount for one
of them still succeeds: the runtime creates an anonymous volume and the artifacts are written there.
The container then has to be kept, or the artifacts copied out with `podman cp`, before removal.

## Paths inside the image

| Path | What it is |
|---|---|
| `/usr/bin/rpmbuilder` | The entrypoint script, and the image's `CMD`. |
| `/usr/bin/rpmbuilder-configure` | The provisioning script. It runs once at image build time and is not part of a build run. |

## Environment set by the image

| Variable | Value |
|---|---|
| `SOURCES` | `/sources` |
| `OUTPUT` | `/output` |
| `EXTRA_PACKAGES` | the build argument passed at image build time |

## Build directories

The entrypoint asks rpm for its configured directories rather than assuming them:

```bash
rpm --eval '%{_sourcedir}'   # where sources and generated specs go
rpm --eval '%{_rpmdir}'      # where binary RPMs are written
rpm --eval '%{_srcrpmdir}'   # where source RPMs are written
```

The values follow the image's own rpm configuration, which differs between the Red Hat and openSUSE
families. Each is a container path, not a host path: the artifacts reach the host only through the
`/output` mount.

## Installed packages

The base distribution supplies the package manager; the provisioning script adds the packaging
toolchain:

| Family | Notable packages |
|---|---|
| Fedora, Rocky Linux | `rpm-build`, `rpmdevtools`, `rpmlint`, `yum-utils`, `ca-certificates`, and on Fedora the `builddep` and `copr` command plugins |
| openSUSE | `rpm-build`, `rpmdevtools`, `rpmlint`, `ca-certificates`, `shadow`, plus `gzip`, `tar`, `curl`, and `which` |

On Rocky Linux the EPEL repository is enabled first, because `rpmlint` and `rpmdevtools` are not in
the base repositories. On any `dnf` system the `fedora-cisco-openh264` repository is disabled,
because its packages are not needed and their metadata otherwise leaks into builds.

## The image is disposable

The container filesystem is writable, and a build installs packages into it. That is the point: the
toolchain never touches the host. It also means the image's own filesystem is not pristine after a
run, which is why a reproducible build starts a fresh container. [Iterating on a
package](../usage/iterating.md) covers the trade-off.

## Next

- [Image tags](image-tags.md) for the available distributions.
- [Environment variables](environment-variables.md) for what the entrypoint reads at runtime.
