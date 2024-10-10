#!/bin/bash

PID_FILE=${PID_FILE:-"/dev/stdout"}
echo "$$" >${PID_FILE}

PID_RES_FILE=${PID_RES_FILE:-"/dev/stdout"}

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")

. ${SCRIPT_DIR}/env.sh

. ${SCRIPT_DIR}/basegrastate.sh

check-safebootstrap() {
  (check-galera-safebootstrap 2>&1 || true) >"${PID_RES_FILE}"
}

check-seqno() {
  (check-galera-seqno 2>&1 || true) >"${PID_RES_FILE}"
}

main() {
  if [[ -z "${1-}" ]]; then
    echo "Usage: $0 {check-safebootstrap|check-seqno}"
    exit 1
  fi

  case "${1-}" in
  check-safebootstrap)
    check-safebootstrap
    ;;
  check-seqno)
    check-seqno
    ;;
  *)
    echo "The operation: ${1-} is not supported!"
    ;;
  esac
}

main "$@"
