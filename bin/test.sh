#!/usr/bin/env bash

set -ex

TARGET_IMAGE=${2:-${TARGET_IMAGE:-$USER/rpmbuilder}}

docker run --rm -i -e OUTPUT_USER=1500 --entrypoint bash ${TARGET_IMAGE} -s <<EOF
set -exo pipefail
shopt -s globstar extglob nullglob

curl --silent --output \$SOURCES/hello.spec \
  https://raw.githubusercontent.com/abn/hello-rpm/master/hello.spec

/usr/bin/rpmbuilder

[ "\$(ls -A \$OUTPUT)" ]
PACKAGE_MANAGER=$({ command -v dnf > /dev/null 2>&1 && echo "dnf"; } || echo "yum")
\$PACKAGE_MANAGER -y install \$OUTPUT/!(*.src).rpm
EOF
