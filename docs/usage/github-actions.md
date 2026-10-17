---
type: Guide
title: GitHub Actions integration
description: Build RPMs in CI with the reusable workflow for matrix builds or the composite action for a single step.
status: stable
tags: [rpm, ci]
---

# GitHub Actions integration

rpmbuilder ships two things a workflow can consume: a reusable workflow that builds across a matrix
of images, and a composite action that runs a single build. Both are referenced by path, not from the
Marketplace.

## Option A: the reusable workflow

Call `abn/rpmbuilder/.github/workflows/rpm-build.yml` to build against several images and upload the
artifacts:

```yaml
jobs:
  build-rpms:
    uses: abn/rpmbuilder/.github/workflows/rpm-build.yml@main
    with:
      sources-path:   rpm
      images:         '["fedora-latest", "fedora-rawhide", "rockylinux-9", "opensuse-leap-15.6"]'
      copr-repos:     '@fedora-llvm-team/llvm-snapshots'
      rpm-lint:       true
      tito-two-stage: false
```

| Input | Required | Default | Purpose |
|---|---|---|---|
| `sources-path` | yes | | path to the sources directory, relative to the repository root |
| `images` | no | `["fedora-latest","rockylinux-9"]` | JSON array of image tag suffixes, each resolved to `quay.io/abn/rpmbuilder:<suffix>` |
| `tito-two-stage` | no | `false` | run the [strict two-stage build](two-stage-tito.md) |
| `arch` | no | `x86_64` | target architecture for every matrix entry |
| `rpm-lint` | no | `false` | run `rpmlint` on each built package |
| `copr-repos` | no | `''` | COPR projects to enable |
| `repos` | no | `''` | custom repository URLs to enable |
| `upload-artifacts` | no | `true` | upload the built RPMs, named `rpms-<image-tag>` |
| `artifact-retention-days` | no | `7` | retention for the uploaded artifacts |

Each matrix entry is one job, named after the image. Failures do not stop the other images, so one
bad distribution does not hide the state of the rest. In two-stage mode the intermediate SRPMs are
uploaded as `srpms-<image-tag>`.

## Option B: the composite action

Use `abn/rpmbuilder/.github/actions/build` for a single step inside a pipeline you control:

```yaml
- name: Build RPMs
  id: rpm
  uses: abn/rpmbuilder/.github/actions/build@main
  with:
    image:       quay.io/abn/rpmbuilder:fedora-latest
    sources-dir: ${{ github.workspace }}/rpm
    mode:        auto
    copr-repos:  '@fedora-llvm-team/llvm-snapshots'
    rpm-lint:    'true'
```

| Input | Required | Default | Purpose |
|---|---|---|---|
| `sources-dir` | yes | | spec and sources, a tito project root, or a directory of `.src.rpm` files in `from-srpm` mode |
| `image` | no | `quay.io/abn/rpmbuilder:fedora-latest` | fully qualified image reference |
| `output-dir` | no | `${{ github.workspace }}/rpmbuild-output` | where the artifacts are written; created if absent |
| `mode` | no | `auto` | `auto`, `srpm-only`, or `from-srpm` |
| `arch` | no | `x86_64` | target architecture |
| `rpm-lint` | no | `false` | run `rpmlint` on each built package |
| `ca-certs-dir` | no | `''` | host directory of `.crt` files to mount into the trust store |
| `copr-repos` | no | `''` | COPR projects to enable |
| `repos` | no | `''` | custom repository URLs to enable |

The action exposes `output-dir`, `rpm-files`, `srpm-files`, `rpm-count`, and `srpm-count`, and writes
a summary table of the artifacts to the job summary.

`mode` maps onto the container's environment: `srpm-only` sets `SRPM_ONLY`, `from-srpm` sets
`FROM_SRPM`, and `auto` detects spec versus tito from the sources directory. An unrecognised value
fails the step immediately.

### Two-stage builds in CI

The action is one container run, so a strict two-stage build is the action used twice: first with
`mode: srpm-only` pointing at the project, then with `mode: from-srpm` pointing at the first run's
output directory. The reusable workflow's `tito-two-stage` input does exactly that.

## Runner requirements

The ubuntu runners on GitHub have podman preinstalled, so no setup step is needed. The action
installs podman itself on a runner that lacks it. For a private registry, run
`redhat-actions/podman-login` before the action; it authenticates the same podman store the build
reads.

## Pin the ref

Both examples use `@main`. Pin to a tag or a commit SHA for a build that does not change underneath
you, and let Dependabot keep the pin current.

## Next

- [Strict two-stage tito builds](two-stage-tito.md) for what `tito-two-stage` proves.
- [Reference: image tags](../reference/image-tags.md) for the values to put in `images`.
