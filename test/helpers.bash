TARGET_IMAGE="${TARGET_IMAGE:-${USER}/rpmbuilder}"
CONTAINER_CLI="${CONTAINER_CLI:-$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)}"

# Single-quoted to preserve literal $ for container-side shell expansion.
# shellcheck disable=SC2016
CONTAINER_PREAMBLE='set -exo pipefail
shopt -s globstar extglob nullglob
PKG_MGR=$({ command -v dnf > /dev/null 2>&1 && echo "dnf"; } || echo "yum")'

rpmbuilder_run() {
  "${CONTAINER_CLI}" run --rm -i "$@" --entrypoint bash "${TARGET_IMAGE}" -s
}

container_script() {
  printf '%s\n' "$@"
}
