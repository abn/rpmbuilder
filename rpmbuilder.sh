#!/usr/bin/env bash

# use exit codes of failing commands
set -exo pipefail

# enable bash options
shopt -s globstar extglob nullglob

SOURCES=${1:-${SOURCES:-$PWD}}
OUTPUT=${OUTPUT:-${SOURCES}/.rpmbuild}
ARCH=${ARCH:-x86_64}
USER=${USER:-root}
OUTPUT_USER=${OUTPUT_USER:-${USER}}

RPM_BUILD_SOURCES=$(rpm  --eval '%{_sourcedir}')
RPM_BUILD_RPMS=$(rpm --eval '%{_rpmdir}')
RPM_BUILD_SRPMS=$(rpm --eval '%{_srcrpmdir}')

install \
  --directory \
  "${SOURCES}" "${OUTPUT}" \
  "${RPM_BUILD_SOURCES}" "${RPM_BUILD_RPMS}" "${RPM_BUILD_SRPMS}"

{ command -v dnf > /dev/null 2>&1 && DNF=1; } || :

# prepare builddep-command
BUILDDEP_CMD=()
if [[ $EUID -ne 0 ]]; then
  BUILDDEP_CMD+=(sudo)
fi


{ [[ -n "${DNF}" ]] && BUILDDEP_CMD+=(dnf builddep); } \
  || BUILDDEP_CMD+=(yum-builddep)

if [[ -n "${ARCH}" ]] && [[ "${ARCH}" != "noarch" ]]; then
  { [[ -n "${DNF}" ]] && BUILDDEP_CMD+=(--forcearch "${ARCH}"); } \
    ||  BUILDDEP_CMD+=(--target "${ARCH}")
fi

function build-from-spec() {
  local specFile=$1

  # install build requires
  "${BUILDDEP_CMD[@]}" -y "$specFile"

  # fetch any external source files
  spectool --sourcedir --get-files "$specFile"

  # build SRPM, also allows to fail quicker
  rpmbuild -bs "$specFile"

  if [[ -z ${SRPM_ONLY} ]]; then
    # attempting to build RPM now
    rpmbuild -ba --target ${ARCH}  "$specFile"
  fi

  # ensure we retrieve only files we build
  mapfile -t prefixes < <(rpm --specfile "$specFile" --queryformat '%{name}-%{version}-%{release}\n')

  for prefix in "${prefixes[@]}"; do
    # make use of globstar to find all rpms with the required prefix
    for rpm in "${RPM_BUILD_SRPMS}"/"${prefix}"*.rpm "${RPM_BUILD_RPMS}"/**/"${prefix}"*.rpm; do
      if  [[ -n "${RPM_LINT}" ]]; then
        # lint was requested
        rpmlint --verbose --info "$rpm"
      fi

      # copy over rpm to output directory with correct ownership
      install \
        --owner "${OUTPUT_USER}" --group "${OUTPUT_USER}" \
        --target-directory "${OUTPUT}" \
        "$rpm"
    done
  done

}

sourceFiles=("${SOURCES}"/!(*.spec))
specFiles=("${SOURCES}"/*.spec)

# copy any non spec files to sources directory
for src in "${sourceFiles[@]}"; do
  cp -R -t "${RPM_BUILD_SOURCES}" "$src"
done

# set required permissions
chown -R "${USER}:${USER}" "${RPM_BUILD_SOURCES}"

for specFile in "${specFiles[@]}"; do
  build-from-spec "$specFile"
done
