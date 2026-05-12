#!/usr/bin/env bats

load helpers

# Shared tito setup: install git, clone test repo, invoke rpmbuilder.
# Single-quoted to preserve literal $ for container-side shell expansion.
# shellcheck disable=SC2016
TITO_CLONE_BUILD='${PKG_MGR} -y install git
git clone https://github.com/abn/hello-rpm-tito.git "${SOURCES}"
/usr/bin/rpmbuilder'

setup_file() {
  export SRPM_DIR="${BATS_SUITE_TMPDIR}/srpm"
  export OUTPUT_DIR="${BATS_SUITE_TMPDIR}/output"
  mkdir -p "${SRPM_DIR}" "${OUTPUT_DIR}"
}

@test "one-stage tito build produces installable RPMs" {
  # shellcheck disable=SC2016
  local assert_rpms='[ "$(ls -A ${OUTPUT})" ]
${PKG_MGR} -y install ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run -e OUTPUT_USER=1500 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${TITO_CLONE_BUILD}" "${assert_rpms}")"
  [ "$status" -eq 0 ]
}

@test "tito one-shot RPM build skips SRPM stage" {
  # shellcheck disable=SC2016
  local assert='! compgen -G "${OUTPUT}/*.src.rpm" > /dev/null
[ "$(ls -A ${OUTPUT})" ]
${PKG_MGR} -y install ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run -e OUTPUT_USER=1500 -e TITO_RPM_ONLY=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${TITO_CLONE_BUILD}" "${assert}")"
  [ "$status" -eq 0 ]
}

@test "two-stage tito build: stage 1 produces SRPM" {
  # shellcheck disable=SC2016
  run rpmbuilder_run \
    -v "${SRPM_DIR}":/output:z \
    -e OUTPUT_USER=1500 \
    -e SRPM_ONLY=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${TITO_CLONE_BUILD}" \
      'compgen -G "${OUTPUT}/*.src.rpm" > /dev/null')"
  [ "$status" -eq 0 ]
}

@test "two-stage tito build: stage 2 rebuilds RPM from SRPM" {
  # shellcheck disable=SC2016
  local rebuild_commands='/usr/bin/rpmbuilder
[ "$(ls -A ${OUTPUT})" ]
${PKG_MGR} -y install ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run \
    -v "${SRPM_DIR}":/sources:z \
    -v "${OUTPUT_DIR}":/output:z \
    -e OUTPUT_USER=1500 \
    -e FROM_SRPM=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${rebuild_commands}")"
  [ "$status" -eq 0 ]
}
