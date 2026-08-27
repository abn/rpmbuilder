#!/usr/bin/env bash

set -exo pipefail

if command -v zypper >/dev/null 2>&1; then
  PACKAGE_MANAGER="zypper"
elif command -v dnf >/dev/null 2>&1; then
  PACKAGE_MANAGER="dnf"
else
  PACKAGE_MANAGER="yum"
fi

SYSTEM_CPE=""
if [[ -f /etc/system-release-cpe ]]; then
  SYSTEM_CPE=$(cat /etc/system-release-cpe)
elif [[ -f /etc/os-release ]]; then
  SYSTEM_CPE=$(grep -E '^CPE_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi

if [[ "${PACKAGE_MANAGER}" == "zypper" ]]; then
  zypper --non-interactive --gpg-auto-import-keys refresh
  zypper --non-interactive update
  zypper --non-interactive install --no-recommends \
    ca-certificates rpm-build rpmdevtools rpmlint shadow gzip tar curl which ${EXTRA_PACKAGES}
  zypper --non-interactive clean --all

  if ! command -v spectool >/dev/null 2>&1 && command -v rpmdev-spectool >/dev/null 2>&1; then
    ln -s "$(command -v rpmdev-spectool)" /usr/bin/spectool
  fi
else
  if [[ "${SYSTEM_CPE}" == *":centos:8" ]]; then
    # convert to centos stream for
    ${PACKAGE_MANAGER} -y \
      --disablerepo '*' \
      --enablerepo=extras swap centos-linux-repos centos-stream-repos
    ${PACKAGE_MANAGER} -y distrosync
  fi

  if [[ "${SYSTEM_CPE}" == *":rocky:"* ]] || [[ "${SYSTEM_CPE}" == *":centos:"* ]]; then
    ${PACKAGE_MANAGER} -y install "epel-release"
  fi

  ${PACKAGE_MANAGER} -y update

  if [[ "${PACKAGE_MANAGER}" == "dnf" ]]; then
    ${PACKAGE_MANAGER} -y install "dnf-command(builddep)"
  fi

  ${PACKAGE_MANAGER} -y install ca-certificates rpm-build rpmdevtools yum-utils rpmlint ${EXTRA_PACKAGES}
  ${PACKAGE_MANAGER} -y clean all
fi

install -d "${SOURCES}" "${OUTPUT}"
