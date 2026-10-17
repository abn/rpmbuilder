---
type: Guide
title: Debugging a build
description: Get an interactive shell, trace the entrypoint with DEBUG, lint the artifacts, and read the common failures.
status: stable
tags: [rpm, debugging]
---

# Debugging a build

A failed container run removes its own state with `--rm`, and the log scrolls past. These are the
tools for looking inside instead.

## Get an interactive shell

Override the entrypoint and drive the build by hand:

```bash
podman run --rm -it --entrypoint bash \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  quay.io/abn/rpmbuilder:fedora-latest
```

Inside the container, `/usr/bin/rpmbuilder` is the same entrypoint the image runs, so you can run it,
watch where it stops, then repeat the failing command yourself. The build tree is left behind on
failure, so `%{_sourcedir}`, `%{_rpmdir}`, and the generated files are all there to inspect.

Drop `--rm` instead when you want the whole container to survive, then re-enter it with
`podman exec -it <name> bash`.

## Trace the entrypoint

Set `DEBUG` or `VERBOSE` to any value to turn on `set -x` in the entrypoint:

```bash
podman run --rm -it \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env DEBUG=1 \
  quay.io/abn/rpmbuilder:fedora-latest
```

Every command is echoed with its expanded arguments, which is the quickest way to see which
repository, which build dependency, or which source URL the run actually used.

## Lint the artifacts

Set `RPM_LINT` and the entrypoint runs `rpmlint --verbose --info` on each artifact it publishes, both
binary RPMs and SRPMs. A non-zero `rpmlint` exit fails the run.

```bash
podman run --rm -it \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env RPM_LINT=1 \
  quay.io/abn/rpmbuilder:fedora-latest
```

## Common failures

| Symptom | Look at |
|---|---|
| the run exits 0 but the output directory is empty | whether a spec file was actually in the sources directory; the spec path builds `"${SOURCES}"/*.spec` |
| `permission denied` on a mount | the `:z` suffix, or `--security-opt label=disable`, on an SELinux host |
| a build dependency cannot be found | the repository step, traced with `DEBUG`; see [Enabling COPR and custom repositories](repositories.md) |
| a source download fails | whether the URL is reachable from the container, and whether its CA is mounted, see [Corporate and self-signed certificates](certificates.md) |
| `rpmbuild --rebuild` fails on an SRPM | the SRPM is malformed, or its spec needs a macro or a build dependency that is not installed |
| tito builds a version you did not expect | uncommitted or untagged work; tito reads git, not the working tree |

## Next

- [Iterating on a package](iterating.md) to stop paying setup cost on every attempt.
- [Reference: environment variables](../reference/environment-variables.md) for the full list, including the diagnostic ones.
