---
type: Guide
title: Iterating on a package
description: Keep one container alive between builds so tito provisioning, package downloads, and the package manager cache are reused.
status: stable
tags: [rpm, podman]
---

# Iterating on a package

A fresh container pays three costs every time: starting, installing the build dependencies, and, for a
tito project, provisioning tito. When you are editing a spec and rerunning the build, start the
container once and run the entrypoint inside it as often as you like.

## Start a long-lived container

Run the image with a command that keeps it alive, named so you can refer to it later:

```bash
podman run -d --name rpmbuilder-work \
  --volume "${PWD}:/sources:z" \
  --volume "${PWD}/output:/output:z" \
  --env OUTPUT_USER="$(id -u)" \
  quay.io/abn/rpmbuilder:fedora-latest \
  sleep inf
```

## Run a build inside it

```bash
podman exec -it rpmbuilder-work rpmbuilder
```

The first run installs the build dependencies and any runtime provisioning. Later runs reuse the
package manager cache in the same container, so they go straight to resolving what changed. The
output directory on the host is updated each time.

Get a shell inside the same container when you need to inspect state:

```bash
podman exec -it rpmbuilder-work bash
```

## Edit and rerun

The sources directory is a bind mount, so an edit on the host is visible in the container
immediately. For a spec build, edit the spec and run `podman exec` again. For a local tarball, change
the file in place.

For a tito project there is one extra rule: commit before each build. tito builds from the committed
tree, so an uncommitted spec is ignored. The loop is edit, commit, `podman exec`.

## Clean up

```bash
podman rm -f rpmbuilder-work
```

The output directory on the host is untouched, and the container's caches go away with it.

## When not to use this

A build that must be reproducible should start from a fresh container every time, which is what the
[quickstart](quickstart.md) and the [GitHub Actions integration](github-actions.md) both do. Use the
long-lived container as a development convenience, not as the thing that produces a release.

## Next

- [Debugging a build](debugging.md) for the shell and tracing tools that pair with this.
- [Building a tito project](tito-builds.md) for the commit rule in context.
