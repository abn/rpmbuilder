[![](https://github.com/abn/rpmbuilder/workflows/Image%20Build/badge.svg)](https://github.com/abn/rpmbuilder/actions?query=workflow%3A%22Image+Build%22)
[![Quay Container](https://quay.io/repository/abn/rpmbuilder/status "Quay Container")](https://quay.io/repository/abn/rpmbuilder)
[![Docker Pulls](https://img.shields.io/docker/pulls/alectolytic/rpmbuilder.svg)](https://hub.docker.com/r/alectolytic/rpmbuilder/)

# RPM build containers for Red Hat based various distros

### Available versions

Available versions can be located by
visiting [Quay Container Repository](https://quay.io/repository/abn/rpmbuilder?tab=tags).

### Fetch image

```bash
BUILDER_VERSION=centos-7
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

This command will drop you into a bash shell within the container. From here, you can execute `build` to build the spec
file. You can also iteratively modify the specfile and re-run `build`.

## Configuration

The following configurations are available via environment variables

| Variable   | Description                                                                                      |
|:-----------|:-------------------------------------------------------------------------------------------------|
| SOURCES    | Configure source directory on the container file system                                          |
| OUTPUT     | Configure output directory on the container file system                                          |
| RPM_LINT   | If set, enables rpm linting once rpms are built                                                  |
| ARCH       | Target architecture to build the rpm for, defaults to `x86_64`                                  |
| SRPM_ONLY  | If set, only builds and outputs the SRPM; skips binary RPM build                                 |
| FROM_SRPM  | If set, treats `SOURCES` as a directory of `.src.rpm` files and rebuilds RPMs from them; use with the base image as stage 2 of the [two-stage tito workflow](#two-stage-tito-workflow-strict-dependency-isolation) |

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
