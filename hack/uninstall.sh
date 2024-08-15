#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}


export CLEAN_MYDATA_ONINSTALL=${CLEAN_MYDATA_ONINSTALL:-"0"}
export STOPMY_ONINSTALL=${STOPMY_ONINSTALL:-"0"}
export MYSQLD_DATADIR=/var/lib/mysql

GALERA_NAME=${GALERA_NAME:-"galera-4"}
GALERA_VERSION=${GALERA_VERSION:-"26.4.19"}

MYSQL_WSREP_NAME=${MYSQL_WSREP_NAME:-"mysql-wsrep-8.0"}
MYSQL_WSREP_VERSION=${MYSQL_WSREP_VERSION:-"8.0.37"}

uninstall-app() {
  if [[ "1" == "${STOPMY_ONINSTALL}" ]]; then
    hack/run.sh stop
  else
    local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
    if [[ "${service_status}" != "inactive" ]] && [[ "${service_status}" != "dead" ]]; then
      echo "Service mysqld has not been shutdown completed!" >&2
      exit 1
    fi
  fi

  yum -y remove "${GALERA_NAME}-${GALERA_VERSION}"
  if rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &> /dev/null; then
    echo "Remove Galera4 failed!" >&2
    exit 1
  fi

  yum -y remove "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}"
  if rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &> /dev/null; then
    echo "Remove Mysql_Wserp failed!" >&2
    exit 1
  fi
  
  if [[ "1" == "${CLEAN_MYDATA_ONINSTALL}" ]]; then
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
