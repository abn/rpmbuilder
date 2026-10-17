---
type: Reference
title: Source configuration files
description: The .copr, .copr-repos, .repos, .repos.list, and .repos/*.repo files read from the sources directory.
status: stable
tags: [reference, configuration, copr]
---

# Source configuration files

The sources directory can carry repository configuration next to the spec. The entrypoint reads it
on every run, merges it with the matching environment variables, and applies it before resolving any
build dependency. See [Enabling COPR and custom repositories](../usage/repositories.md) for the task
version of this page.

## Files

| Path | Format | Enables |
|---|---|---|
| `.copr` | one `owner/project` or `@group/project` per line | COPR projects |
| `.copr-repos` | an alias for `.copr` | COPR projects |
| `.repos` | one repository URL per line | custom repositories |
| `.repos.list` | an alias for `.repos` | custom repositories |
| `.repos/*.repo` | `.repo` files | the repositories those files define |

## Parsing rules

- A `#` starts a comment and the rest of the line is ignored.
- Spaces are stripped from each line.
- An empty line, or a line that is only a comment, is skipped.
- The files and the environment variables are merged. Setting `COPR_REPOS` does not suppress a
  committed `.copr` file.

## Drop-in `.repo` files

A `.repo` file in `.repos/` is copied into the package manager's repository directory:
`/etc/yum.repos.d` on an `dnf` or `yum` system, `/etc/zypp/repos.d` on a `zypper` system. The file's
own contents decide the repository definition, so this is the form to use when a repository needs
GPG keys, priority, or an `enabled` flag set explicitly.

## Configuration is not a build source

`.copr`, `.copr-repos`, `.repos`, `.repos.list`, and the `.repos/` directory are excluded from the
copy into the build tree, so they do not end up in the build environment or the source package. They
are hidden files, and the copy step reads only the visible entries of the sources directory.

## Next

- [Enabling COPR and custom repositories](../usage/repositories.md) for worked examples.
- [Environment variables](environment-variables.md) for the matching variables.
