---
type: Guide
title: Contributing
description: Branches, commits, tests, and documentation, and what a change needs before it is ready for review.
status: stable
tags: [project, contributing]
---

# Contributing

rpmbuilder is maintained in a single repository and takes changes as pull requests against `main`.

## Scope of a change

One change is one topic. A bug fix and a refactor that happens to sit nearby are two changes. The
smallest correct version of a change is the one that gets reviewed fastest, so leave a reformat or a
rename out unless the change needs it.

## Branch and commit

- Branch from the latest `main`, and use a hyphenated conventional name: `fix/srpm-subpackages`,
  `feat/repo-config`, `docs/usage-guides`.
- Commit messages use a conventional prefix that names the area: `fix:`, `feat:`, `test:`, `ci:`,
  `docs:`. Look at the existing history for the tone; the subject line states the outcome.
- Keep the history to the logical units of the change. If review produces a correction, fix it up
  into the commit it belongs to rather than adding a commit named after the review.

## Tests

Build the image and run the BATS suite as [Testing](testing.md) describes. A change to the
entrypoint needs a test on the path it touches, and a change to an action or a workflow is exercised
by `action-test.yml`.

Tests run in containers. Do not add a test that installs packages on the host or that depends on the
previous test's state.

## Documentation

The documentation in this bundle is the reference for the public interface. A change that alters an
environment variable, an action input, an image tag, or a build path updates the matching page in
the same pull request:

| Change | Page |
|---|---|
| A new or renamed environment variable | [Environment variables](../reference/environment-variables.md) |
| A new repository configuration file or parsing rule | [Source configuration files](../reference/source-config-files.md) |
| A new image tag or a dropped distribution | [Image tags](../reference/image-tags.md) |
| A change to how a build path works | The matching page under [Usage](../usage/index.md) |
| A change to the entrypoint's structure | [Architecture](architecture.md) |

The bundle is validated and rendered by `okf-wiki`. After editing it:

```bash
okf validate docs/
```

Every page carries frontmatter with a `type`, every new page is linked from its section's
`index.md`, and a change to the bundle adds a dated entry to `docs/log.md`.

## The public interface

These are the parts a consumer depends on, so a change to them is a compatibility question, not
just an implementation detail:

- the environment variables in [Environment variables](../reference/environment-variables.md);
- the inputs, outputs, and modes of the actions under `.github/`;
- the published image tag names;
- the mount points `/sources` and `/output`.

A rename or a removal in that list is a breaking change and needs a note in the pull request that
says so.

## Next

- [Testing](testing.md) for the suite and its fixtures.
- [Architecture](architecture.md) for the code the change will touch.
