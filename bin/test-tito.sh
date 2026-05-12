#!/usr/bin/env bash

set -ex

TARGET_IMAGE=${2:-${TARGET_IMAGE:-$USER/rpmbuilder}}

# Test: single-container tito build (tito installed at runtime)
docker run --rm -i -e OUTPUT_USER=1500 --entrypoint bash "${TARGET_IMAGE}" -s <<'EOF'
set -exo pipefail
shopt -s globstar extglob nullglob

PACKAGE_MANAGER=$({ command -v dnf > /dev/null 2>&1 && echo "dnf"; } || echo "yum")
${PACKAGE_MANAGER} -y install git

git clone https://github.com/abn/hello-rpm-tito.git "${SOURCES}"

/usr/bin/rpmbuilder

[ "$(ls -A ${OUTPUT})" ]
${PACKAGE_MANAGER} -y install ${OUTPUT}/!(*.src).rpm
EOF

# Test: two-stage build with strict dependency isolation
SRPM_DIR=$(mktemp -d)
OUTPUT_DIR=$(mktemp -d)
trap "rm -rf ${SRPM_DIR} ${OUTPUT_DIR}" EXIT

# Stage 1: generate SRPM; tito installed at runtime, sources cloned inside container
docker run --rm -i \
  -v "${SRPM_DIR}":/output:z \
  -e OUTPUT_USER=1500 \
  -e SRPM_ONLY=1 \
  --entrypoint bash "${TARGET_IMAGE}" -s <<'EOF'
set -exo pipefail
shopt -s globstar extglob nullglob

PACKAGE_MANAGER=$({ command -v dnf > /dev/null 2>&1 && echo "dnf"; } || echo "yum")
${PACKAGE_MANAGER} -y install git

git clone https://github.com/abn/hello-rpm-tito.git "${SOURCES}"

/usr/bin/rpmbuilder

compgen -G "${OUTPUT}/*.src.rpm" > /dev/null
EOF

# Stage 2: rebuild RPM from SRPM in a clean environment
docker run --rm -i \
  -v "${SRPM_DIR}":/sources:z \
  -v "${OUTPUT_DIR}":/output:z \
  -e OUTPUT_USER=1500 \
  -e FROM_SRPM=1 \
  --entrypoint bash "${TARGET_IMAGE}" -s <<'EOF'
set -exo pipefail
shopt -s globstar extglob nullglob

/usr/bin/rpmbuilder

[ "$(ls -A ${OUTPUT})" ]
PACKAGE_MANAGER=$({ command -v dnf > /dev/null 2>&1 && echo "dnf"; } || echo "yum")
$PACKAGE_MANAGER -y install ${OUTPUT}/!(*.src).rpm
EOF
