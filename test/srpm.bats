#!/usr/bin/env bats

load helpers

setup_file() {
  # The two-stage tests form a producer->consumer pair: "stage 1" writes the
  # SRPM into SRPM_DIR and "stage 2" reads it back. bats --jobs >1 would run
  # them concurrently with no ordering guarantee, so stage 2 can start before
  # stage 1 has written the SRPM. Keep this file's tests serial (cross-file
  # parallelism with spec.bats and tito.bats is unaffected).
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export FIXTURE_DIR="${BATS_FILE_TMPDIR}/sources"
  export SRPM_DIR="${BATS_FILE_TMPDIR}/srpm"
  export OUTPUT_DIR="${BATS_FILE_TMPDIR}/output"
  mkdir -p "${FIXTURE_DIR}" "${SRPM_DIR}" "${OUTPUT_DIR}"
  # copy the fixture so mounting it never writes into the source tree
  cp "${BATS_TEST_DIRNAME}/multi.spec" "${FIXTURE_DIR}/"
}

@test "two-stage multi-subpackage build: stage 1 produces SRPM" {
  # shellcheck disable=SC2016
  local spec_commands='/usr/bin/rpmbuilder
compgen -G "${OUTPUT}/*.src.rpm"'

  run rpmbuilder_run \
    -v "${FIXTURE_DIR}":/sources:z \
    -v "${SRPM_DIR}":/output:z \
    -e OUTPUT_USER=1500 \
    -e SRPM_ONLY=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${spec_commands}")"
  [ "$status" -eq 0 ]
}

@test "two-stage multi-subpackage build: stage 2 publishes every subpackage" {
  # shellcheck disable=SC2016
  local rebuild_commands='/usr/bin/rpmbuilder
[ "$(ls -A ${OUTPUT})" ]
compgen -G "${OUTPUT}/multi-a-*.rpm"
compgen -G "${OUTPUT}/multi-b-*.rpm"
compgen -G "${OUTPUT}/multi-*.src.rpm"
${PKG_INSTALL} ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run \
    -v "${SRPM_DIR}":/sources:z \
    -v "${OUTPUT_DIR}":/output:z \
    -e OUTPUT_USER=1500 \
    -e FROM_SRPM=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" "${rebuild_commands}")"
  [ "$status" -eq 0 ]
}
