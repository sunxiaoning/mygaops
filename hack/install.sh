#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

RPMREPO_MODULE=rpmrepo

export WEB_PROTOCOL=${WEB_PROTOCOL:-http}
export SERVER_NAME=${SERVER_NAME:-localhost}
export USE_REPO_SERVER=${USE_REPO_SERVER:-0}

export MYSQLD_DATADIR=/var/lib/mysql
export MYSQLD_SOCKET=${MYSQLD_SOCKET:-/var/lib/mysql/mysql.sock}
export MYSQLD_BIND_ADDRESS=${MYSQLD_BIND_ADDRESS:-0.0.0.0}
export MYSQLD_INNODB_BUFFER_POOL_SIZE=${MYSQLD_INNODB_BUFFER_POOL_SIZE:-122M}
export MYSQLD_WSREP_PROVIDER=${MYSQLD_WSREP_PROVIDER:-/usr/lib64/galera-4/libgalera_smm.so}
export MYSQLD_MYSQLD_WSREP_PROVIDER_OPTIONS=${MYSQLD_MYSQLD_WSREP_PROVIDER_OPTIONS:-gcache.size=300M; gcache.page_size=300M}
export MYSQLD_WSREP_CLUSTER_NAME=${MYSQLD_WSREP_CLUSTER_NAME:-galera-cluster}
export MYSQLD_WSREP_CLUSTER_ADDRESS=${MYSQLD_WSREP_CLUSTER_ADDRESS:-}
export MYSQLD_WSREP_NODE_NAME=${MYSQLD_WSREP_NODE_NAME:-$(hostname)}
export MYSQLD_WSREP_NODE_ADDRESS=${MYSQLD_WSREP_NODE_ADDRESS:-$(hostname -I | awk '{print $1}')}

export STOPMY_ONINSTALL=${STOPMY_ONINSTALL:-"0"}

PROJECT_PATH=$(pwd)

GALERA_NAME=${GALERA_NAME:-"galera-4"}
GALERA_VERSION=${GALERA_VERSION:-"26.4.19"}

MYSQL_WSREP_NAME=${MYSQL_WSREP_NAME:-"mysql-wsrep-8.0"}
MYSQL_WSREP_VERSION=${MYSQL_WSREP_VERSION:-"8.0.37"}

install-repo() {
  cd "${RPMREPO_MODULE}"

  # TODO
  make install-repogalera4
  yum clean all &> /dev/null;
  yum makecache
  cd "${PROJECT_PATH}"
}

install-app() {
  if [[ "1" == "${STOPMY_ONINSTALL}" ]]; then
    hack/run.sh stop
  else
    local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
    if [[ "${service_status}" != "inactive" ]] && [[ "${service_status}" != "dead" ]]; then
      echo "Service mysqld has not been shutdown completed!"
      exit 1
    fi
  fi

  dnf -y module disable mysql mariadb &> /dev/null;

  echo "Install ${GALERA_NAME}-${GALERA_VERSION} ..."
  bashutils/yuminstaller.sh "${GALERA_NAME}" "${GALERA_VERSION}"

  echo "Install ${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} ..."
  bashutils/yuminstaller.sh "${MYSQL_WSREP_NAME}" "${MYSQL_WSREP_VERSION}"

  dnf -y module enable mysql mariadb &> /dev/null;
}

install-conf() {
  if ! rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &> /dev/null; then
    echo "${GALERA_NAME}-${GALERA_VERSION} has not been installed yet!"
    exit 1
  fi
  if ! rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &> /dev/null; then
    echo "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} has not been installed yet!"
    exit 1
  fi
  bashutils/render.sh conf/my.cnf.tmpl "conf/my.cnf"
  install -D -m 644 "conf/my.cnf" "/etc/my.cnf" 
}


main() {
  if [[ "1" == "${USE_DOCKER}" ]]; then
    echo "Begin to build with docker."
    case "${1-}" in
    repo)
      install-repo-docker
      ;;
    app)
      install-app-docker
      ;;
    conf)
      install-conf-docker
      ;;
    *)
      install-repo-docker
      install-app-docker
      install-conf-docker
      ;;
    esac
  else
    echo "Begin to build in the local environment."
    case "${1-}" in
    repo)
      install-repo
      ;;
    app)
      install-app
      ;;
    conf)
      install-conf
      ;;
    *)
      install-repo
      install-app
      install-conf
      ;;
    esac
  fi
}

main "$@"
