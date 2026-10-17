---
type: Runbook
title: Testing
description: What the BATS suite covers, which public fixtures it uses, and how to run it without touching the host.
status: stable
tags: [project, ci]
---

# Testing

The suite is BATS, and every test runs the real image in a real container. Nothing is installed on
the host, and no test reads or writes host state outside a temporary directory.

## The fixtures

Two public repositories supply the inputs, so the tests need network access:

| Fixture | Shape | Used by |
|---|---|---|
| `abn/hello-rpm` | a single `.spec` file with a remote `Source0` | `test/spec.bats` |
| `abn/hello-rpm-tito` | a tito project with a `.tito` directory | `test/tito.bats` |

The spec test writes the fixture spec into `SOURCES` and runs `/usr/bin/rpmbuilder` inside the
container, then asserts that the output directory holds a binary RPM. The tito tests clone the tito
fixture and assert the same, plus the two-stage pair.

## The two-stage pair

`test/tito.bats` holds three tests, two of which form a producer and a consumer pair that must run in
order: stage 1 writes an SRPM, stage 2 reads it back. Cross-file parallelism is fine, but within the
file the tests are pinned serial, because `bats --jobs` gives no ordering guarantee and stage 2 could
otherwise start before stage 1 has written anything.

## Running it

Build the image first, then run the suite against it:

```bash
BASE_IMAGE=quay.io/fedora/fedora:latest \
TARGET_IMAGE=localhost/rpmbuilder:fedora-latest \
make build

TARGET_IMAGE=localhost/rpmbuilder:fedora-latest make test
```

`make test` runs `bats --jobs 2 --print-output-on-failure test/`, so the two files run in parallel and
a failure prints its full container log. `CONTAINER_CLI` selects `podman` or `docker`, and defaults
to whichever is found.

A single test can be selected with the usual BATS filter:

```bash
TARGET_IMAGE=localhost/rpmbuilder:fedora-latest \
  bats --filter "one-stage tito" test/tito.bats
```

## What CI runs

| Workflow | Purpose |
|---|---|
| `image-build.yml` | Builds each distribution and version in the matrix, runs this suite against it, and pushes the image and the multi-architecture manifest on `main`. |
| `action-test.yml` | Exercises the composite actions end to end against the same fixtures, using an image built from the branch under test. |

The action tests assert the action's own behaviour: mode handling, podman invocation, and the
reported artifact counts, including the two-stage composition.

## Adding a test

Put it in the file that matches the path it covers, and keep it container-only. A test that installs
a package on the host, or that depends on state left by another test, does not belong in this suite.
Where a fixture needs a full git history, say so in the test: tito derives the version from tags.

## Next

- [Architecture](architecture.md) for the layers under test.
- [Contributing](contributing.md) for when a change needs a new test.
