#!/usr/bin/env bash

set -exo pipefail

PACKAGE_MANAGER=$({ command -v dnf > /dev/null 2>&1 && echo "dnf"; } || echo "yum")
SYSTEM_CPE=$(cat /etc/system-release-cpe)

if [[ "${SYSTEM_CPE}" == *":centos:"* ]]; then
  ${PACKAGE_MANAGER} -y install "epel-release"
fi

${PACKAGE_MANAGER} -y update

if [[ "${PACKAGE_MANAGER}" == "dnf" ]]; then
  ${PACKAGE_MANAGER} -y install "dnf-command(builddep)"
fi

${PACKAGE_MANAGER} -y install rpm-build rpmdevtools yum-utils rpmlint ${EXTRA_PACKAGES}

${PACKAGE_MANAGER} -y clean all

install -d "${SOURCES}" "${OUTPUT}"