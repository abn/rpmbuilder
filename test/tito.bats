#!/usr/bin/env bats

load helpers

# Shared tito setup: install git, clone test repo, invoke rpmbuilder.
# Single-quoted to preserve literal $ for container-side shell expansion.
# shellcheck disable=SC2016
TITO_CLONE_BUILD='${PKG_INSTALL} git
git clone https://github.com/abn/hello-rpm-tito.git "${SOURCES}"
/usr/bin/rpmbuilder'

setup_file() {
  # The two-stage tests form a producer->consumer pair: "stage 1" writes the
  # SRPM into SRPM_DIR and "stage 2" reads it back. bats --jobs >1 would run
  # them concurrently with no ordering guarantee, so stage 2 can start before
  # stage 1 has written the SRPM. Keep this file's tests serial (cross-file
  # parallelism with spec.bats is unaffected).
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export SRPM_DIR="${BATS_SUITE_TMPDIR}/srpm"
  export OUTPUT_DIR="${BATS_SUITE_TMPDIR}/output"
  mkdir -p "${SRPM_DIR}" "${OUTPUT_DIR}"
}

@test "one-stage tito build produces installable RPMs" {
  # shellcheck disable=SC2016
  local assert_rpms='[ "$(ls -A ${OUTPUT})" ]
${PKG_INSTALL} ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run -e OUTPUT_USER=1500 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${TITO_CLONE_BUILD}" "${assert_rpms}")"
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
${PKG_INSTALL} ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run \
    -v "${SRPM_DIR}":/sources:z \
    -v "${OUTPUT_DIR}":/output:z \
    -e OUTPUT_USER=1500 \
    -e FROM_SRPM=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${rebuild_commands}")"
  [ "$status" -eq 0 ]
}
