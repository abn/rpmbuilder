#!/usr/bin/env bats

load helpers

setup_file() {
  # each fixture gets its own producer (sources -> srpm) and consumer
  # (srpm -> output) directory so the two stages never share state
  export INJECT_SOURCES="${BATS_FILE_TMPDIR}/inject-sources"
  export INJECT_SRPM="${BATS_FILE_TMPDIR}/inject-srpm"
  export INJECT_OUTPUT="${BATS_FILE_TMPDIR}/inject-output"
  export DEBUG_SOURCES="${BATS_FILE_TMPDIR}/debug-sources"
  export DEBUG_SRPM="${BATS_FILE_TMPDIR}/debug-srpm"
  export DEBUG_OUTPUT="${BATS_FILE_TMPDIR}/debug-output"
  export OUTSIDE_SOURCES="${BATS_FILE_TMPDIR}/outside-sources"
  export OUTSIDE_SRPM="${BATS_FILE_TMPDIR}/outside-srpm"
  export OUTSIDE_OUTPUT="${BATS_FILE_TMPDIR}/outside-output"
  mkdir -p \
    "${INJECT_SOURCES}" "${INJECT_SRPM}" "${INJECT_OUTPUT}" \
    "${DEBUG_SOURCES}" "${DEBUG_SRPM}" "${DEBUG_OUTPUT}" \
    "${OUTSIDE_SOURCES}" "${OUTSIDE_SRPM}" "${OUTSIDE_OUTPUT}"
  # copy the fixtures so mounting them never writes into the source tree
  cp "${BATS_TEST_DIRNAME}/inject.spec" "${INJECT_SOURCES}/"
  cp "${BATS_TEST_DIRNAME}/debug.spec" "${DEBUG_SOURCES}/"
  cp "${BATS_TEST_DIRNAME}/outside.spec" "${OUTSIDE_SOURCES}/"
}

build_srpm() {
  local sources=$1 srpm_dir=$2

  rpmbuilder_run \
    -v "${sources}":/sources:z \
    -v "${srpm_dir}":/output:z \
    -e OUTPUT_USER=1500 \
    -e SRPM_ONLY=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" '/usr/bin/rpmbuilder')"
}

rebuild_srpm() {
  local srpm_dir=$1 output_dir=$2

  rpmbuilder_run \
    -v "${srpm_dir}":/sources:z \
    -v "${output_dir}":/output:z \
    -e OUTPUT_USER=1500 \
    -e FROM_SRPM=1 \
    <<< "$(container_script "${CONTAINER_PREAMBLE}" '/usr/bin/rpmbuilder')"
}

@test "rebuild-from-srpm ignores Wrote: lines emitted by build scripts" {
  run build_srpm "${INJECT_SOURCES}" "${INJECT_SRPM}"
  [ "$status" -eq 0 ]

  run rebuild_srpm "${INJECT_SRPM}" "${INJECT_OUTPUT}"
  [ "$status" -eq 0 ]

  # the real package is published
  compgen -G "${INJECT_OUTPUT}/inject-*.noarch.rpm" > /dev/null
  # none of the paths printed by the build script are
  [ ! -e "${INJECT_OUTPUT}/passwd" ]
  [ ! -e "${INJECT_OUTPUT}/inject-evil.rpm" ]
  [ ! -e "${INJECT_OUTPUT}/inject-link.rpm" ]
}

@test "rebuild-from-srpm fails when no package is publishable" {
  run build_srpm "${OUTSIDE_SOURCES}" "${OUTSIDE_SRPM}"
  [ "$status" -eq 0 ]

  run rebuild_srpm "${OUTSIDE_SRPM}" "${OUTSIDE_OUTPUT}"
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "${OUTSIDE_OUTPUT}")" ]
}

@test "rebuild-from-srpm publishes debuginfo and debugsource packages" {
  run build_srpm "${DEBUG_SOURCES}" "${DEBUG_SRPM}"
  [ "$status" -eq 0 ]

  run rebuild_srpm "${DEBUG_SRPM}" "${DEBUG_OUTPUT}"
  [ "$status" -eq 0 ]

  compgen -G "${DEBUG_OUTPUT}/*-debuginfo-*.rpm" > /dev/null
  compgen -G "${DEBUG_OUTPUT}/*-debugsource-*.rpm" > /dev/null
}
