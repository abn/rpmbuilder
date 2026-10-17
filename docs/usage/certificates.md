---
type: Guide
title: Corporate and self-signed certificates
description: Trust a private CA inside the container before any download or dependency install runs.
status: stable
tags: [rpm, configuration, tls]
---

# Corporate and self-signed certificates

If a `Source` URL or a package repository is served with a certificate from a private CA, the
container needs that CA in its trust store. rpmbuilder looks for mounted certificates at startup and
refreshes the trust store before it fetches sources or installs packages.

## Steps

1. Collect the CA certificates as `.crt` files in one host directory.
2. Mount that directory at the anchor path that matches the image family:

   | Image family | Anchor directory |
   |---|---|
   | Fedora, Rocky Linux, and other Red Hat derived images | `/etc/pki/ca-trust/source/anchors` |
   | openSUSE | `/etc/pki/trust/anchors` |

3. Run as usual:

   ```bash
   podman run --rm -it \
     --volume "${PWD}/sources:/sources:z" \
     --volume "${PWD}/output:/output:z" \
     --volume "${PWD}/ca:/etc/pki/ca-trust/source/anchors:z" \
     --env OUTPUT_USER="$(id -u)" \
     quay.io/abn/rpmbuilder:fedora-latest
   ```

## What the entrypoint does with them

It checks both anchor directories in turn. When one contains files, it refreshes the trust store with
`update-ca-trust extract` or `update-ca-certificates`, whichever the distribution provides, and stops
checking. A directory with no certificates is skipped, so mounting an empty one is harmless.

## Reading files from a plain HTTP source

A private CA does not help when the URL has an `http` scheme rather than `https`. There is nothing to
verify in that case, and the download simply proceeds.

## Next

- [Enabling COPR and custom repositories](repositories.md) for the repository side of a private network.
- [Debugging a build](debugging.md) when a download still fails after the certificates are mounted.
