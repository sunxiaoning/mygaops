#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")

. hack/env.sh

CLEAN_DATA_ON_UNINSTALL=${CLEAN_DATA_ON_UNINSTALL:-"0"}
STOP_SERV_ON_UNINSTALL=${STOP_SERV_ON_UNINSTALL:-"0"}

uninstall-app() {
  if [[ "1" == "${STOP_SERV_ON_UNINSTALL}" ]]; then
    hack/run.sh stop
  else
    local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
    if [[ "${service_status}" != "inactive" ]] && [[ "${service_status}" != "dead" ]]; then
      echo "Service mysqld has not been shutdown completed!" >&2
      exit 1
    fi
  fi

  yum -y remove "${GALERA_NAME}-${GALERA_VERSION}"
  if rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "Remove Galera4 failed!" >&2
    exit 1
  fi

  yum -y remove "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}"
  if rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "Remove Mysql_Wserp failed!" >&2
    exit 1
  fi

  if [[ "1" == "${CLEAN_DATA_ON_UNINSTALL}" ]]; then
    echo "[Warning] Clean old MySQL datadir ..."
    rm -rf ${MYSQLD_DATADIR}
  fi
}

main() {
  if [[ "1" == "${USE_DOCKER}" ]]; then
    echo "Begin to build with docker."
    case "${1-}" in
    app)
      uninstall-app-docker
      ;;
    *)
      uninstall-app-docker
      ;;
    esac
  else
    echo "Begin to build in the local environment."
    case "${1-}" in
    app)
      uninstall-app
      ;;
    *)
      uninstall-app
      ;;
    esac
  fi
}

main "$@"
