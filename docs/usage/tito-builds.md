---
type: Guide
title: Building a tito project
description: Let tito derive the version and changelog from git, with rpmbuilder provisioning tito at runtime.
status: stable
tags: [rpm, tito]
---

# Building a tito project

When the sources directory contains a `.tito` directory, the entrypoint switches to the tito path
instead of the spec path. Nothing else in the invocation changes: the same mounts from the
[quickstart](quickstart.md) are all you need.

## What the entrypoint does

1. Checks for `tito` and installs it if it is missing (see [tito availability](#tito-availability)).
2. Runs `tito build --test --srpm` from the sources directory.
3. Unless `SRPM_ONLY` is set, runs `tito build --test --rpm`.
4. Installs the resulting `.rpm` and `.src.rpm` files into the output directory.

tito writes to a temporary directory inside the container; the entrypoint publishes the artifacts
afterwards, so the output directory ends up with the same layout as a spec build.

## tito builds from git, not from the working tree

> [!IMPORTANT]
> Commit your changes before running the build. tito reads the committed tree, so an uncommitted
> spec edit is invisible and the build silently reflects the last commit.

The tito build also reads tags, so a shallow clone with no tags produces a different version string.
When you fetch the project yourself, use a full clone. A dirty working tree can make tito refuse to
build outright, so keep temporary files out of the tree with `.gitignore`.

## The changelog belongs to tito

Do not hand-edit the `%changelog` section of the spec. `tito tag` writes it during release, and a
manual entry duplicates or reorders it. For local verification builds, leave the changelog alone.

## tito availability

rpmbuilder provisions tito at runtime when the image does not already carry it. It tries the
distribution package first and falls back to `pip` when the package manager cannot provide one:

| Distribution | How tito arrives |
|---|---|
| Fedora | the distribution package |
| Rocky Linux 9 | the distribution package, via EPEL |
| Rocky Linux 10, openSUSE | `pip`, with a fallback for PEP 668 managed environments |

This happens inside the container for the duration of the run, so it costs a little time on the
first build of a session. [Iterating on a package](iterating.md) shows how to avoid paying it
repeatedly.

## SRPM only

`SRPM_ONLY` stops after step 2, which is the first half of a
[strict two-stage build](two-stage-tito.md):

```bash
podman run --rm -it \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env SRPM_ONLY=1 \
  quay.io/abn/rpmbuilder:fedora-latest
```

## Why isolate a tito build

tito and its Python dependencies are installed into the build environment. Any of them can satisfy a
`BuildRequires` your spec never declared, so a plain tito build can succeed with a spec that would
fail on a clean system. [Strict two-stage tito builds](two-stage-tito.md) removes that risk.

## Next

- [Strict two-stage tito builds](two-stage-tito.md) for the clean-environment rebuild.
- [GitHub Actions integration](github-actions.md) to run this on every push.
