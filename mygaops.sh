#!/bin/bash

CONTEXT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename "$0")

. ${CONTEXT_DIR}/bashutils/basicenv.sh

OPS_SH_DIR="${CONTEXT_DIR}/ops"

. "${OPS_SH_DIR}/env.sh"

. "${OPS_SH_DIR}/install.sh"

. "${OPS_SH_DIR}/run.sh"

. "${OPS_SH_DIR}/uninstall.sh"

TEMP_FILES=()

trap __terminate INT TERM
trap __cleanup EXIT

autoinstall() {
  install-app
  install-conf
}

autorun() {
  autoinstall
  start
}

restart() {
  stop
  start
}

main() {
  case "${1-}" in
  install-galera4-repo)
    install-galera4-repo
    ;;
  install-mysql-wsrep8-repo)
    install-mysql-wsrep8-repo
    ;;
  install-app)
    install-app
    ;;
  install-conf)
    install-conf
    ;;
  autoinstall)
    autoinstall
    ;;
  start)
    start
    ;;
  init-server)
    init-server
    ;;
  reinit-server)
    reinit-server
    ;;
  reset-password)
    reset-password
    ;;
  autorun)
    autorun
    ;;
  check-node)
    check-node
    ;;
  check-galera-safebootstrap)
    check-galera-safebootstrap
    ;;
  check-galera-seqno)
    check-galera-seqno
    ;;
  check-cluster)
    check-cluster
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  uninstall-app)
    uninstall-app
    ;;
  uninstall-galera4-repo)
    uninstall-galera4-repo
    ;;
  uninstall-mysql-wsrep8-repo)
    uninstall-mysql-wsrep8-repo
    ;;
  uninstall-app-repo)
    uninstall-app-repo
    ;;
  *)
    echo "The operation: ${1-} is not supported!"
    exit 1
    ;;
  esac
}

terminate() {
  echo "terminating..."
}

cleanup() {
  if [[ "${#TEMP_FILES[@]}" -gt 0 ]]; then
    echo "Cleaning temp_files...."

    for temp_file in "${TEMP_FILES[@]}"; do
      rm -f "${temp_file}" || true
    done
  fi
}

main "$@"
