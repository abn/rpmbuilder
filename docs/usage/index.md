# Usage

Task-oriented guides. Build the quickstart first, then pick the guide that matches your project.

## First steps

- [Quickstart](quickstart.md) - Mount your sources and an output directory, run the image, and collect the RPMs it produces.
- [Iterating on a package](iterating.md) - Keep one container alive between builds so tito provisioning, package downloads, and the package manager cache are reused.

## Build paths

- [Building from a spec file](spec-builds.md) - The default path, which resolves BuildRequires, fetches remote sources, and publishes every subpackage the spec defines.
- [Building a tito project](tito-builds.md) - Let tito derive the version and changelog from git, with rpmbuilder provisioning tito at runtime.
- [Strict two-stage tito builds](two-stage-tito.md) - Generate an SRPM with tito, then rebuild it in a clean container so only declared BuildRequires can be satisfied.
- [Rebuilding from an SRPM](rebuild-from-srpm.md) - Compile binary RPMs from existing .src.rpm files without the original sources or spec tree.

## Repositories and environment

- [Enabling COPR and custom repositories](repositories.md) - Add COPR projects and custom package repositories before build dependencies are resolved.
- [Corporate and self-signed certificates](certificates.md) - Trust a private CA inside the container before any download or dependency install runs.
- [Building for another architecture](architectures.md) - Target aarch64, noarch, or another architecture with the ARCH variable instead of a different image.

## Operating

- [Debugging a build](debugging.md) - Get an interactive shell, trace the entrypoint with DEBUG, lint the artifacts, and read the common failures.
- [GitHub Actions integration](github-actions.md) - Build RPMs in CI with the reusable workflow for matrix builds or the composite action for a single step.

## Before publishing

- [Testing before publishing with coprctl](coprctl.md) - Use coprctl to run this same image locally before a Copr build, so a spec is tested before it reaches the build queue.
