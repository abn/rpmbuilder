#!/usr/bin/env bats

load helpers

@test "spec build produces installable RPMs" {
  # shellcheck disable=SC2016
  local spec_commands='curl --silent --output "${SOURCES}/hello.spec" https://raw.githubusercontent.com/abn/hello-rpm/master/hello.spec
/usr/bin/rpmbuilder
[ "$(ls -A ${OUTPUT})" ]
${PKG_INSTALL} ${OUTPUT}/!(*.src).rpm'

  run rpmbuilder_run -e OUTPUT_USER=1500 <<< "$(container_script "${CONTAINER_PREAMBLE}" "${spec_commands}")"
  [ "$status" -eq 0 ]
}

@test "dynamically enables repository via REPOS" {
  # shellcheck disable=SC2016
  local spec_commands='curl --silent --output "${SOURCES}/hello.spec" https://raw.githubusercontent.com/abn/hello-rpm/master/hello.spec
/usr/bin/rpmbuilder
[ "$(ls -A ${OUTPUT})" ]
if [ -d /etc/yum.repos.d ]; then
  ls /etc/yum.repos.d/*.repo
elif [ -d /etc/zypp/repos.d ]; then
  ls /etc/zypp/repos.d/*.repo
fi'

  run rpmbuilder_run -e REPOS="http://example.com/custom.repo" -e OUTPUT_USER=1500 <<< "$(container_script "${CONTAINER_PREAMBLE}" "${spec_commands}")"
  [ "$status" -eq 0 ]
}

@test "dynamically enables custom repository via .repos directory" {
  # shellcheck disable=SC2016
  local spec_commands='mkdir -p "${SOURCES}/.repos"
cat << "REPOEOF" > "${SOURCES}/.repos/custom.repo"
[custom-test]
name=Custom Test Repo
baseurl=https://raw.githubusercontent.com/abn/hello-rpm/master
enabled=0
gpgcheck=0
REPOEOF
curl --silent --output "${SOURCES}/hello.spec" https://raw.githubusercontent.com/abn/hello-rpm/master/hello.spec
/usr/bin/rpmbuilder
[ "$(ls -A ${OUTPUT})" ]'

  run rpmbuilder_run -e OUTPUT_USER=1500 <<< "$(container_script "${CONTAINER_PREAMBLE}" "${spec_commands}")"
  [ "$status" -eq 0 ]
}
