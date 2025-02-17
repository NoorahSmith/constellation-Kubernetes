#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
REPOSITORY_ROOT="${REPOSITORY_ROOT:-$(cd "${SCRIPT_DIR}" && git rev-parse --show-toplevel)}"

goos() {
  case "$(uname -sr)" in
  Darwin*) echo 'darwin' ;;
  Linux*) echo 'linux' ;;
  *)
    echo 'Unknown OS' >&2
    exit 1
    ;;
  esac
}

goarch() {
  case $(uname -m) in
  x86_64) echo 'amd64' ;;
  arm) echo 'arm64' ;; # this is slightly simplified, but we only care about arm64
  arm64) echo 'arm64' ;;
  *)
    echo 'Unknown arch' >&2
    exit 1
    ;;
  esac
}

need_pseudo_version_tool() {
  if [[ ! -f "${REPOSITORY_ROOT}/tools/pseudo-version" ]]; then
    return 1
  fi

  expected=$(cat "${REPOSITORY_ROOT}/tools/pseudo_version_$(goos)_$(goarch).sha256")
  local need_pseudo_version_tool=0
  if type sha256sum > /dev/null 2>&1; then
    need_pseudo_version_tool=$(sha256sum -c --status <(echo "${expected}  ${REPOSITORY_ROOT}/tools/pseudo-version") && echo 0 || echo 1)
  elif type shasum > /dev/null 2>&1; then
    need_pseudo_version_tool=$(shasum -a 256 -c --status <(echo "${expected}  ${REPOSITORY_ROOT}/tools/pseudo-version") && echo 0 || echo 1)
  else
    echo "sha256sum or shasum is required to verify the pseudo-version tool" >&2
    exit 1
  fi

  return "${need_pseudo_version_tool}"
}

# shellcheck disable=SC2310
ensure_pseudo_version_tool() {
  local should_download=0
  should_download=$(need_pseudo_version_tool && echo 0 || echo 1)

  if [[ ${should_download} -ne 0 ]]; then
    get_pseudo_version_tool
  fi
}

get_pseudo_version_tool() {
  out="${REPOSITORY_ROOT}/tools/pseudo-version"
  hash=$(cat "${REPOSITORY_ROOT}/tools/pseudo_version_$(goos)_$(goarch).sha256")
  url=https://cdn.confidential.cloud/constellation/cas/sha256/${hash}
  if command -v curl &> /dev/null; then
    curl -fsSL "${url}" -o "${out}"
  elif command -v wget &> /dev/null; then
    wget -q -O "${out}" "${url}"
  else
    echo "curl or wget is required to download the pseudo-version tool" >&2
    exit 1
  fi
  chmod +x "${out}"
}

pseudo_version() {
  ensure_pseudo_version_tool
  "${REPOSITORY_ROOT}/tools/pseudo-version" -skip-v
}

timestamp() {
  ensure_pseudo_version_tool
  "${REPOSITORY_ROOT}/tools/pseudo-version" -print-timestamp -timestamp-format '2006-01-02T15:04:05Z07:00'
}

echo "REPO_URL https://github.com/edgelesssys/constellation.git"
echo "STABLE_STAMP_COMMIT $(git rev-parse HEAD)"
echo "STABLE_STAMP_STATE $(git update-index -q --really-refresh && git diff-index --quiet HEAD -- && echo "clean" || echo "dirty")"
echo "STABLE_STAMP_VERSION $(pseudo_version)"
echo "STABLE_STAMP_TIME $(timestamp)"
