#!/usr/bin/env bats

load helpers

@test "spec build produces installable RPMs" {
  # shellcheck disable=SC2016
  local spec_commands='curl --silent --output "${SOURCES}/hello.spec" https://raw.githubusercontent.com/abn/hello-rpm/master/hello.spec
/usr/bin/rpmbuilder
[ "$(ls -A ${OUTPUT})" ]
${PKG_MGR} -y install ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run -e OUTPUT_USER=1500 <<< "$(container_script "${CONTAINER_PREAMBLE}" "${spec_commands}")"
  [ "$status" -eq 0 ]
}
