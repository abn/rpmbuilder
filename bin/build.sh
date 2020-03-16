#!/usr/bin/env bash

set -ex

BASE_IMAGE=${1:-${BASE_IMAGE:-fedora}}
TARGET_IMAGE=${2:-${TARGET_IMAGE:-$USER/rpmbuilder}}
EXTRA_PACKAGES=${EXTRA_PACKAGES:-""}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

docker build -t ${TARGET_IMAGE} -f - ${DIR}/../ << EOF
FROM ${BASE_IMAGE}

ARG EXTRA_PACKAGES

ENV SOURCES=/sources
ENV OUTPUT=/output

COPY ./bin/configure.sh /usr/bin/rpmbuilder-configure
RUN rpmbuilder-configure

COPY ./rpmbuilder.sh /usr/bin/rpmbuilder

VOLUME \${SOURCES}
VOLUME \${OUTPUT}

CMD /usr/bin/rpmbuilder
EOF
