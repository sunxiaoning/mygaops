#!/bin/bash
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename "$0")

. ${SCRIPT_DIR}/bashutils/basicenv.sh

trap __terminate INT TERM
trap __cleanup EXIT

HACK_SH_DIR="${SCRIPT_DIR}/ops"
INSTALL_SH_FILE="${HACK_SH_DIR}/install.sh"
RUN_SH_FILE="${HACK_SH_DIR}/run.sh"
UNINSTALL_SH_FILE="${HACK_SH_DIR}/uninstall.sh"

install-repo() {
  echo "Install repo ..."

  "${INSTALL_SH_FILE}" repo &

  wait $!
}

install-app() {
  install-repo

  echo "Install app ..."

  "${INSTALL_SH_FILE}" app &

  wait $!
}

install-conf() {
  echo "Install conf ..."

  "${INSTALL_SH_FILE}" conf &

  wait $!
}

install() {
  install-app
  install-conf
}

start() {
  echo "Start server ..."

  "${RUN_SH_FILE}" start &

  wait $!
}

init-server() {
  echo "Init server ..."

  "${RUN_SH_FILE}" init &

  wait $!
}

reinit-server() {
  echo "Reinit server ..."

  "${RUN_SH_FILE}" reinit &

  wait $!
}

reset-password() {
  echo "Reset password ..."

  "${RUN_SH_FILE}" reset-password &

  wait $!
}

autorun() {
  install
  start
}

check-node() {
  echo "Check node mysql-wsrep status ..."

  "${RUN_SH_FILE}" check-node &

  wait $!
}

check-galera-safebootstrap() {
  stop

  echo "Check galera safebootstrap ..."

  "${RUN_SH_FILE}" check-galera-safebootstrap &

  wait $!
}

check-galera-seqno() {
  stop

  echo "Check galera seqno ..."

  "${RUN_SH_FILE}" check-galera-seqno &

  wait $!
}

check-cluster() {
  echo "Check cluster mysql-wsrep status ..."

  "${RUN_SH_FILE}" check-cluster &

  wait $!
}

stop() {
  echo "Stop server ..."

  "${RUN_SH_FILE}" stop &

  wait $!
}

restart() {
  stop
  start
}

uninstall-app() {
  echo "Uninstall app ..."

  "${UNINSTALL_SH_FILE}" app &

  wait $!
}

main() {
  case "${1-}" in
  install-repo)
    install-repo
    ;;
  install-app)
    install-app
    ;;
  install-conf)
    install-conf
    ;;
  install)
    install
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
  echo "cleanup..."
}

main "$@"
