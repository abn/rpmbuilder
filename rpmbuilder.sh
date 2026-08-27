#!/usr/bin/env bash

# use exit codes of failing commands
set -eo pipefail
[[ -n "${DEBUG:-}" || -n "${VERBOSE:-}" ]] && set -x

# enable bash options
shopt -s globstar extglob nullglob

SOURCES=${1:-${SOURCES:-$PWD}}
OUTPUT=${OUTPUT:-${SOURCES}/.rpmbuild}
ARCH=${ARCH:-$(uname -m)}
USER=${USER:-root}
OUTPUT_USER=${OUTPUT_USER:-${USER}}

RPM_BUILD_SOURCES=$(rpm  --eval '%{_sourcedir}')
RPM_BUILD_RPMS=$(rpm --eval '%{_rpmdir}')
RPM_BUILD_SRPMS=$(rpm --eval '%{_srcrpmdir}')

install \
  --directory \
  "${SOURCES}" "${OUTPUT}" \
  "${RPM_BUILD_SOURCES}" "${RPM_BUILD_RPMS}" "${RPM_BUILD_SRPMS}"

if command -v dnf > /dev/null 2>&1; then
  DNF=1
elif command -v zypper > /dev/null 2>&1; then
  ZYPPER=1
fi

CA_ANCHORS_DIRS=("/etc/pki/ca-trust/source/anchors" "/etc/pki/trust/anchors")
for dir in "${CA_ANCHORS_DIRS[@]}"; do
  if compgen -G "${dir}/*" > /dev/null 2>&1; then
    UPDATE_CA_CMD=()
    [[ $EUID -ne 0 ]] && UPDATE_CA_CMD+=(sudo)
    if command -v update-ca-trust > /dev/null 2>&1; then
      UPDATE_CA_CMD+=(update-ca-trust extract)
    elif command -v update-ca-certificates > /dev/null 2>&1; then
      UPDATE_CA_CMD+=(update-ca-certificates)
    fi
    if [[ ${#UPDATE_CA_CMD[@]} -gt 0 ]]; then
      "${UPDATE_CA_CMD[@]}"
    fi
    break
  fi
done

function publish_artifact() {
  local rpmFile=$1
  if [[ -n "${RPM_LINT}" ]]; then
    rpmlint --verbose --info "$rpmFile"
  fi

  local install_opts=(--target-directory "${OUTPUT}")
  if [[ $EUID -eq 0 ]] && [[ -n "${OUTPUT_USER}" ]]; then
    install_opts+=(--owner "${OUTPUT_USER}" --group "${OUTPUT_USER}")
  fi
  install "${install_opts[@]}" "$rpmFile"
}

function install-builddep() {
  local targetFile=$1
  local SUDO_CMD=()
  [[ $EUID -ne 0 ]] && SUDO_CMD+=(sudo)

  if [[ -n "${ZYPPER}" ]]; then
    local deps=()
    if [[ "$targetFile" == *.src.rpm ]]; then
      mapfile -t deps < <(rpm -qp --requires "$targetFile" 2>/dev/null | grep -v '^rpmlib(' || true)
    else
      mapfile -t deps < <(rpmspec -q --buildrequires "$targetFile" 2>/dev/null | grep -v '^rpmlib(' || true)
    fi
    if [[ ${#deps[@]} -gt 0 ]]; then
      "${SUDO_CMD[@]}" zypper --non-interactive install --no-recommends "${deps[@]}"
    fi
  elif [[ -n "${DNF}" ]]; then
    local arch_args=()
    if [[ -n "${ARCH}" ]] && [[ "${ARCH}" != "noarch" ]]; then
      arch_args+=(--forcearch "${ARCH}")
    fi
    "${SUDO_CMD[@]}" dnf builddep "${arch_args[@]}" -y "$targetFile"
  else
    local arch_args=()
    if [[ -n "${ARCH}" ]] && [[ "${ARCH}" != "noarch" ]]; then
      arch_args+=(--target "${ARCH}")
    fi
    "${SUDO_CMD[@]}" yum-builddep "${arch_args[@]}" -y "$targetFile"
  fi
}

function build-from-spec() {
  local specFile=$1

  # build SRPM, also allows to fail quicker
  rpmbuild -bs --target "${ARCH}" "$specFile"

  if [[ -z ${SRPM_ONLY} ]]; then
    # attempting to build RPM now
    rpmbuild -ba --target "${ARCH}"  "$specFile"
  fi

  # ensure we retrieve only files we build
  mapfile -t prefixes < <(rpm --specfile "$specFile" --queryformat '%{name}-%{version}-%{release}\n')

  for prefix in "${prefixes[@]}"; do
    # make use of globstar to find all rpms with the required prefix
    for rpm in "${RPM_BUILD_SRPMS}"/"${prefix}"*.rpm "${RPM_BUILD_RPMS}"/**/"${prefix}"*.rpm; do
      [[ -f "$rpm" ]] && publish_artifact "$rpm"
    done
  done
}

function rebuild-from-srpm() {
  local srpmFiles=("${SOURCES}"/*.src.rpm)

  if [[ ! -f "${srpmFiles[0]}" ]]; then
    echo "FROM_SRPM is set but no .src.rpm files found in ${SOURCES}" >&2
    exit 1
  fi

  for srpm in "${srpmFiles[@]}"; do
    install-builddep "$srpm"
    rpmbuild --rebuild --target "${ARCH}" "$srpm"

    local prefix
    prefix=$(rpm -qp --queryformat '%{name}-%{version}-%{release}' "$srpm")

    for rpm in "${RPM_BUILD_SRPMS}/${prefix}"*.rpm "${RPM_BUILD_RPMS}"/**/"${prefix}"*.rpm; do
      [[ -f "$rpm" ]] && publish_artifact "$rpm"
    done
  done
}

function build-from-tito() {
  if ! command -v tito > /dev/null 2>&1; then
    echo "tito not found. Installing tito..."
    local SUDO_CMD=()
    if [[ $EUID -ne 0 ]]; then
      SUDO_CMD+=(sudo)
    fi

    if [[ -n "${ZYPPER}" ]]; then
      if ! "${SUDO_CMD[@]}" zypper --non-interactive install --no-recommends tito; then
        "${SUDO_CMD[@]}" zypper --non-interactive install --no-recommends python3 python3-pip python3-setuptools python3-curses
        "${SUDO_CMD[@]}" python3 -m pip install --break-system-packages tito 2>/dev/null \
          || "${SUDO_CMD[@]}" python3 -m pip install tito
      fi
    elif { [[ -n "${DNF}" ]] && "${SUDO_CMD[@]}" dnf install -y tito; } \
        || "${SUDO_CMD[@]}" yum install -y tito; then
      :
    else
      local PKG_MGR; [[ -n "${DNF}" ]] && PKG_MGR=dnf || PKG_MGR=yum
      "${SUDO_CMD[@]}" "${PKG_MGR}" install -y python3 python3-setuptools
      python3 -m ensurepip
      "${SUDO_CMD[@]}" python3 -m pip install --break-system-packages tito 2>/dev/null \
        || "${SUDO_CMD[@]}" python3 -m pip install tito
    fi
  fi

  echo "Building tito test release..."
  local TITO_OUTPUT=$(mktemp -d)
  
  pushd "${SOURCES}" >/dev/null
  tito build --test --srpm --output="${TITO_OUTPUT}"
  if [[ -z "${SRPM_ONLY}" ]]; then
    tito build --test --rpm --output="${TITO_OUTPUT}"
  fi
  popd >/dev/null

  # copy over rpm to output directory with correct ownership
  for rpm in "${TITO_OUTPUT}"/**/*.rpm; do
    [[ -f "$rpm" ]] && publish_artifact "$rpm"
  done
}

function enable_repos() {
  local SUDO_CMD=()
  [[ $EUID -ne 0 ]] && SUDO_CMD+=(sudo)

  # 1. Drop-in *.repo files from ${SOURCES}/.repos/
  if compgen -G "${SOURCES}/.repos/*.repo" > /dev/null 2>&1; then
    local repo_dest="/etc/yum.repos.d"
    [[ -n "${ZYPPER}" ]] && repo_dest="/etc/zypp/repos.d"
    "${SUDO_CMD[@]}" install -d "${repo_dest}"
    for r in "${SOURCES}"/.repos/*.repo; do
      "${SUDO_CMD[@]}" cp "$r" "${repo_dest}/"
    done
  fi

  # 2. Custom repository URLs (from ADDITIONAL_REPOS / REPOS and ${SOURCES}/.repos / .repos.list)
  local custom_repos=()
  if [[ -n "${ADDITIONAL_REPOS:-}" ]]; then
    read -r -a env_repos <<< "${ADDITIONAL_REPOS//,/ }"
    custom_repos+=("${env_repos[@]}")
  fi
  if [[ -n "${REPOS:-}" ]]; then
    read -r -a env_repos <<< "${REPOS//,/ }"
    custom_repos+=("${env_repos[@]}")
  fi
  for rfile in "${SOURCES}/.repos" "${SOURCES}/.repos.list"; do
    if [[ -f "$rfile" ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -n "$line" ]] && custom_repos+=("$line")
      done < "$rfile"
    fi
  done

  if [[ ${#custom_repos[@]} -gt 0 ]]; then
    local idx=1
    for r in "${custom_repos[@]}"; do
      if [[ -n "${ZYPPER}" ]]; then
        "${SUDO_CMD[@]}" zypper --non-interactive addrepo --no-gpgcheck "$r" "custom_repo_${idx}" || true
      elif [[ -n "${DNF}" ]]; then
        if [[ "$r" == *.repo ]]; then
          "${SUDO_CMD[@]}" dnf config-manager addrepo --from-repofile="$r" 2>/dev/null \
            || "${SUDO_CMD[@]}" dnf config-manager --add-repo="$r" || true
        else
          "${SUDO_CMD[@]}" dnf config-manager addrepo "$r" 2>/dev/null \
            || "${SUDO_CMD[@]}" dnf config-manager --add-repo="$r" || true
        fi
      else
        "${SUDO_CMD[@]}" yum-config-manager --add-repo="$r" || true
      fi
      ((idx++))
    done
  fi

  # 3. COPR repositories (from COPR_REPOS and ${SOURCES}/.copr / .copr-repos)
  local copr_list=()
  if [[ -n "${COPR_REPOS:-}" ]]; then
    read -r -a env_copr <<< "${COPR_REPOS//,/ }"
    copr_list+=("${env_copr[@]}")
  fi
  for cfile in "${SOURCES}/.copr" "${SOURCES}/.copr-repos"; do
    if [[ -f "$cfile" ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -n "$line" ]] && copr_list+=("$line")
      done < "$cfile"
    fi
  done

  if [[ ${#copr_list[@]} -gt 0 ]]; then
    for copr_repo in "${copr_list[@]}"; do
      read -r -a copr_args <<< "${copr_repo}"
      if [[ -n "${ZYPPER}" ]]; then
        local distro_ver="opensuse-tumbleweed"
        if grep -q "Leap" /etc/os-release 2>/dev/null; then
          local ver_id
          ver_id=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
          distro_ver="opensuse-leap-${ver_id}"
        fi
        local copr_target="${copr_args[0]}"
        local copr_url="https://copr.fedorainfracloud.org/coprs/${copr_target}/repo/${distro_ver}/${copr_target//\//-}-${distro_ver}.repo"
        "${SUDO_CMD[@]}" zypper --non-interactive addrepo --no-gpgcheck "${copr_url}" || true
      elif [[ -n "${DNF}" ]]; then
        "${SUDO_CMD[@]}" dnf copr enable -y "${copr_args[@]}"
      else
        "${SUDO_CMD[@]}" yum copr enable -y "${copr_args[@]}"
      fi
    done
  fi
}

# copy non-spec source files, excluding output dirs, hidden files, and spec files
for src in "${SOURCES}"/*; do
  [[ ! -e "$src" ]] && continue
  [[ "$src" == *.spec ]] && continue
  [[ "$src" == "${OUTPUT}" ]] && continue
  [[ "$(basename "$src")" == .rpmbuild ]] && continue
  [[ "$(basename "$src")" == .copr* ]] && continue
  [[ "$(basename "$src")" == .repos* ]] && continue
  cp -R -t "${RPM_BUILD_SOURCES}" "$src"
done

# set required permissions
chown -R "${USER}:${USER}" "${RPM_BUILD_SOURCES}"

specFiles=("${SOURCES}"/*.spec)

# enable any dynamic or configured repositories
enable_repos

# install build requires and fetch sources for all spec files
for specFile in "${specFiles[@]}"; do
  install-builddep "$specFile"
  SPECTOOL_CMD=$(command -v spectool || command -v rpmdev-spectool)
  "${SPECTOOL_CMD}" --sourcedir --get-files "$specFile"
done

if [[ -n "${FROM_SRPM}" ]]; then
  rebuild-from-srpm
elif [[ -d "${SOURCES}/.tito" ]]; then
  build-from-tito
else
  for specFile in "${specFiles[@]}"; do
    build-from-spec "$specFile"
  done
fi
