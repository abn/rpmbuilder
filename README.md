[![](https://github.com/abn/rpmbuilder/workflows/Image%20Build/badge.svg)](https://github.com/abn/rpmbuilder/actions?query=workflow%3A%22Image+Build%22)
[![Docker Pulls](https://img.shields.io/docker/pulls/alectolytic/rpmbuilder.svg)](https://hub.docker.com/r/alectolytic/rpmbuilder/)

# RPM build containers for Red Hat based various distros

### Available versions
Available versions can be located by visiting [Docker Hub Repository](https://hub.docker.com/r/alectolytic/rpmbuilder/tags/).

### Fetch image
```bash
BUILDER_VERSION=centos-7
docker pull alectolytic/rpmbuilder:${BUILDER_VERSION}
```

### Run
In this example `SOURCE_DIR` contains spec file and sources for the the RPM we are building.

```bash
# set env variables for conviniece
SOURCE_DIR=$(pwd)/sources
OUTPUT_DIR=$(pwd)/output

# create a output directory
mkdir -p ${OUTPUT_DIR}

# build rpm
docker run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    alectolytic/rpmbuilder:${BUILDER_VERSION}
```

The output files will be available in `OUTPUT_DIR`.

###  Debugging
If you are creating a spec file, it is often useful to have a clean room debugging environment. You can achieve this by using the following command.

```bash
docker run --rm -it --entrypoint bash \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    alectolytic/rpmbuilder:${BUILDER_VERSION}
```
This command will drop you into a bash shell within the container. From here, you can execute `build` to build the spec file. You can also iteratively modify the specfile and re-run `build`.

## Configuration
The following configurations are available via environment variables

| Variable  | Description |
| :------------ | :------------ |
| SOURCES | Configure source directory on the container file system |
| OUTPUT | Configure output directory on the container file system |
| RPM_LINT | If set, enables rpm linting once rpms are built |
| ARCH | Target architecture to build the rpm for, defaults to `x86_64` |

## Volumes
The following volumes can be mounted from the host.

| Volume  | Description |
| :------------ | :------------ |
| /sources | Source to build RPM from |
| /output | Output directory where all built RPMs and SRPMs are extracted to |
