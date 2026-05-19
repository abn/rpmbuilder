[![](https://github.com/abn/rpmbuilder/workflows/Image%20Build/badge.svg)](https://github.com/abn/rpmbuilder/actions?query=workflow%3A%22Image+Build%22)
[![Quay Container](https://quay.io/repository/abn/rpmbuilder/status "Quay Container")](https://quay.io/repository/abn/rpmbuilder)

# RPM build containers for Red Hat based various distros

### Available versions

Available versions can be located by
visiting [Quay Container Repository](https://quay.io/repository/abn/rpmbuilder?tab=tags).

### Fetch image

```bash
BUILDER_VERSION=fedora-latest
podman pull quay.io/abn/rpmbuilder:${BUILDER_VERSION}
```

### Run

In this example `SOURCE_DIR` contains spec file and sources for the the RPM we are building.

```bash
# set env variables for convenience
SOURCE_DIR=$(pwd)/sources
OUTPUT_DIR=$(pwd)/output

# create a output directory
mkdir -p ${OUTPUT_DIR}

# build rpm
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    quay.io/abn/rpmbuilder:${BUILDER_VERSION}
```

The output files will be available in `OUTPUT_DIR`.

### Tito projects

For projects managed by [tito](https://github.com/rpm-software-management/tito), use the same image as for spec-based builds. The image detects the presence of a `.tito` directory and automatically installs tito at runtime before building with `tito build --test`:

```bash
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    quay.io/abn/rpmbuilder:${BUILDER_VERSION}
```

> **Note:** tito is available via EPEL on Fedora and EL 8/9 but is not yet available on EL 10 (e.g. Rocky Linux 10).

#### Two-stage tito workflow (strict dependency isolation)

Because tito and its dependencies are installed into the build environment at runtime, they could inadvertently satisfy undeclared `BuildRequires` in a spec file. To ensure only explicitly declared dependencies are used, run the build in two stages: generate the SRPM with tito in the first run, then rebuild the RPM from that SRPM in a second clean run without tito present.

```bash
# Stage 1: generate SRPM using tito
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    -e SRPM_ONLY=1 \
    quay.io/abn/rpmbuilder:${BUILDER_VERSION}

# Stage 2: rebuild RPM from SRPM in a clean environment (no tito)
podman run --rm -it \
    -v ${OUTPUT_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    -e FROM_SRPM=1 \
    quay.io/abn/rpmbuilder:${BUILDER_VERSION}
```

The `FROM_SRPM=1` flag is required and intentional — it prevents the image from accidentally entering SRPM rebuild mode due to leftover `.src.rpm` files in the output directory.

### Debugging

If you are creating a spec file, it is often useful to have a clean room debugging environment. You can achieve this by
using the following command.

```bash
podman run --rm -it --entrypoint bash \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    quay.io/abn/rpmbuilder:${BUILDER_VERSION}
```

This command will drop you into a bash shell within the container. From here, you can execute `rpmbuilder` to build the spec
file. You can also iteratively modify the specfile and re-run `rpmbuilder`.

## GitHub Actions

rpmbuilder ships ready-to-use GitHub Actions so you can build RPMs/SRPMs in
CI without writing container plumbing. They are **consumed by path
reference** (this project publishes a container image, not a Marketplace
action), so reference them as `abn/rpmbuilder/...@<ref>`. Pin to a tag or
commit SHA instead of `@main` for reproducible builds.

| Component | Reference | Use when |
|:----------|:----------|:---------|
| Reusable workflow | [`.github/workflows/rpm-build.yml`](.github/workflows/rpm-build.yml) | You want a turnkey matrix build (multiple images) + artifact upload |
| `build` action | [`.github/actions/build`](.github/actions/build/README.md) | You need a single build step; the `mode` input selects the use case (`auto`, `srpm-only`, `from-srpm`, `tito-one-shot`) |

All actions run the image with **rootless podman** (installed via
`redhat-actions/podman-install` when not preinstalled). For private
registries, call `redhat-actions/podman-login` before them.

### Reusable workflow (fastest path)

Spec-file project, default image matrix:

```yaml
jobs:
  rpm:
    uses: abn/rpmbuilder/.github/workflows/rpm-build.yml@main
    with:
      sources-path: rpm
```

Tito project with strict two-stage isolation across several images:

```yaml
jobs:
  rpm:
    uses: abn/rpmbuilder/.github/workflows/rpm-build.yml@main
    with:
      sources-path:   .
      tito-two-stage: true
      images: '["fedora-44","fedora-rawhide","rockylinux-9"]'
```

Workflow inputs: `sources-path` (required), `images` (JSON array of tag
suffixes, default `["fedora-latest","rockylinux-9"]`), `tito-two-stage`,
`arch`, `rpm-lint`, `upload-artifacts`, `artifact-retention-days`. Built
artifacts are uploaded as `rpms-<image>` (and `srpms-<image>` for two-stage).

### Composite action (single step)

```yaml
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ github.workspace }}/rpm
    mode:        auto   # or: srpm-only | from-srpm | tito-one-shot
```

The action is a single container run. A **strict two-stage tito build**
(generate the SRPM, then rebuild it in a clean environment with no tito) is
just the action used twice — first `mode: srpm-only`, then `mode: from-srpm`
against the first run's output:

```yaml
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ github.workspace }}        # tito project root
    output-dir:  ${{ runner.temp }}/srpm
    mode:        srpm-only
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ runner.temp }}/srpm        # the SRPM from step 1
    output-dir:  ${{ runner.temp }}/rpms
    mode:        from-srpm
```

See the [`build` action README](.github/actions/build/README.md) for the
full input/output reference, the `mode` table, and more examples. The action
is exercised on every PR by
[`.github/workflows/action-test.yml`](.github/workflows/action-test.yml),
which builds the current image and validates the spec, one-shot tito, and
two-stage (composed) paths against canonical fixtures.

## Configuration

The following configurations are available via environment variables

| Variable      | Description |
|:-------------|:------------|
| SOURCES       | Configure source directory on the container file system |
| OUTPUT        | Configure output directory on the container file system |
| OUTPUT_USER   | User or UID that built RPMs and SRPMs are owned by in the output directory; set to your host `$UID` to avoid root-owned files, defaults to the container build user |
| RPM_LINT      | If set, enables rpm linting once rpms are built |
| ARCH          | Target architecture to build the rpm for, defaults to `x86_64` |
| SRPM_ONLY     | If set, only builds and outputs the SRPM; skips binary RPM build |
| FROM_SRPM     | If set, treats `SOURCES` as a directory of `.src.rpm` files and rebuilds RPMs from them; use with the base image as stage 2 of the [two-stage tito workflow](#two-stage-tito-workflow-strict-dependency-isolation) |
| TITO_ONE_SHOT | For tito projects, if set, builds via a single `tito build --rpm` invocation instead of the default separate `tito --srpm` + `tito --rpm` steps. Faster; produces the same artifacts (the SRPM is still emitted alongside the RPM). The former name `TITO_RPM_ONLY` is deprecated but still honoured. |

## Volumes

The following volumes can be mounted from the host.

| Volume                                  | Description                                                      |
|:----------------------------------------|:-----------------------------------------------------------------|
| /sources                                | Source to build RPM from                                         |
| /output                                 | Output directory where all built RPMs and SRPMs are extracted to |
| /etc/pki/ca-trust/source/anchors        | (optional) Directory of `.crt` files to add to the CA trust store before building |

To inject corporate or self-signed CA certificates, mount a directory containing `.crt` files and the trust store will be updated automatically before any build steps run:

```bash
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -v ${CERT_DIR}:/etc/pki/ca-trust/source/anchors:z \
    -e OUTPUT_USER=$UID \
    quay.io/abn/rpmbuilder:${BUILDER_VERSION}
```

## Building the image locally

`make build` builds the image from the committed `Containerfile`. The
container runtime is auto-detected — podman if present, otherwise docker —
and can be forced with `CONTAINER_CLI`:

```bash
# default: auto-detected runtime, Fedora base
make build

# a specific base image and tag
BASE_IMAGE=rockylinux:9 TARGET_IMAGE=rpmbuilder:rocky-9 make build

# force docker instead of the auto-detected podman
CONTAINER_CLI=docker make build
```

`make test` runs the BATS suite against the image (requires a prior `make build`).
