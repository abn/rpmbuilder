---
type: Guide
title: Enabling COPR and custom repositories
description: Add COPR projects and custom package repositories before build dependencies are resolved.
status: stable
tags: [rpm, configuration, copr]
---

# Enabling COPR and custom repositories

A `BuildRequires` that is not in the base distribution has to come from somewhere. rpmbuilder enables
extra repositories, in three kinds, before it resolves any build dependency.

## Pass them in the environment

This is the preferred form: nothing is committed to the source tree and nothing changes on the host.

```bash
podman run --rm -it \
  --volume "${PWD}/sources:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  --env COPR_REPOS="@fedora-llvm-team/llvm-snapshots user/my-repo" \
  --env REPOS="https://example.com/custom.repo" \
  quay.io/abn/rpmbuilder:fedora-latest
```

| Variable | Takes |
|---|---|
| `COPR_REPOS` | a space- or comma-separated list of COPR projects, `user/project` or `@group/project` |
| `REPOS` | a space- or comma-separated list of repository URLs, or of `.repo` file URLs |
| `ADDITIONAL_REPOS` | an alias for `REPOS`, merged with it |

## Or commit them to the sources directory

For a project whose dependencies are stable enough to record, put the configuration next to the
spec:

| Path | Format |
|---|---|
| `.copr` | one COPR project per line, `user/project` |
| `.copr-repos` | an alias for `.copr` |
| `.repos` | one repository URL per line |
| `.repos.list` | an alias for `.repos` |
| `.repos/*.repo` | drop-in `.repo` files, copied into the package manager's repository directory |

All four text files ignore `#` comments and strip whitespace from each line. The environment
variables and the files are merged rather than one overriding the other.

The `.copr*` and `.repos*` entries are configuration inputs, not build sources: they are excluded
from the file copy into the build tree.

## Order of application

The entrypoint enables repositories in this order, then resolves build dependencies:

1. Drop-in `.repo` files from `.repos/`.
2. Custom repository URLs from `REPOS`, `ADDITIONAL_REPOS`, `.repos`, and `.repos.list`.
3. COPR projects from `COPR_REPOS`, `.copr`, and `.copr-repos`.

On a `dnf` system a `.repo` URL is registered with `dnf config-manager`; plain URLs the same way; COPR
projects with `dnf copr enable`. On a `zypper` system repositories are added with
`zypper addrepo --no-gpgcheck`, and a COPR project is translated into its raw `.repo` URL for the
matching openSUSE target, `opensuse-leap-<version>` for Leap or `opensuse-tumbleweed` otherwise.

## GPG checking

On a `zypper` system a repository added at runtime is registered with `--no-gpgcheck`, because
rpmbuilder has no key to verify it with. On a `dnf` system the repository's own `gpgcheck` setting
applies instead: a drop-in `.repo` file keeps whatever it declares, and `dnf copr enable` keeps the
keys the project generates. If your package needs an enforced signature check, build on a host image
that already carries the repository and its key.

## When a repository is not found

A COPR project that does not publish for the target distribution is the usual reason a build fails
right after the repository step. The error comes from the package manager, not from rpmbuilder. Run
with `--entrypoint bash` and repeat the `dnf builddep` or `zypper install` command by hand to see it
clearly, as in [Debugging a build](debugging.md).

## Next

- [Corporate and self-signed certificates](certificates.md) when the repository is reached over TLS with a private CA.
- [GitHub Actions integration](github-actions.md) for the action inputs that carry the same values.
