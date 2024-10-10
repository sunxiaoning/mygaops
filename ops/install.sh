#!/bin/bash
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")

. ops/env.sh

RPMREPO_MODULE=rpmrepo

export REPO_SOURCE=${REPO_SOURCE:-"0"}
export REPO_SERVER_PROTOCOL=${REPO_SERVER_PROTOCOL:-"http"}
export REPO_SERVER_NAME=${REPO_SERVER_NAME:-"localhost"}

export MYSQLD_DATADIR
export MYSQLD_SOCKET=${MYSQLD_SOCKET:-/var/lib/mysql/mysql.sock}

export MYSQLD_BIND_ADDRESS=${MYSQLD_BIND_ADDRESS:-0.0.0.0}
export MYSQLD_INNODB_BUFFER_POOL_SIZE=${MYSQLD_INNODB_BUFFER_POOL_SIZE:-122M}
export MYSQLD_WSREP_PROVIDER=${MYSQLD_WSREP_PROVIDER:-/usr/lib64/galera-4/libgalera_smm.so}
export MYSQLD_MYSQLD_WSREP_PROVIDER_OPTIONS=${MYSQLD_MYSQLD_WSREP_PROVIDER_OPTIONS:-gcache.size=300M; gcache.page_size=300M}
export MYSQLD_WSREP_CLUSTER_NAME=${MYSQLD_WSREP_CLUSTER_NAME:-galera-cluster}
export MYSQLD_WSREP_CLUSTER_ADDRESS=${MYSQLD_WSREP_CLUSTER_ADDRESS:-""}
export MYSQLD_WSREP_NODE_NAME=${MYSQLD_WSREP_NODE_NAME:-$(hostname)}
export MYSQLD_WSREP_NODE_ADDRESS=${MYSQLD_WSREP_NODE_ADDRESS:-$(hostname -I | awk '{print $1}')}

STOP_SERV_ON_INSTALL=${STOP_SERV_ON_INSTALL:-"0"}

PROJECT_PATH=$(pwd)

YUMINSTALLER_SH_FILE="${SCRIPT_DIR}/../bashutils/yuminstaller.sh"
RENDER_SH_FILE="${SCRIPT_DIR}/../bashutils/render.sh"
CHECKHOSTIP_SH_FILE="${SCRIPT_DIR}/../bashutils/checkhostip.sh"

install-repo() {
  cd "${RPMREPO_MODULE}"

  hack/build.sh galera4

  hack/install.sh galera4

  yum clean all &>/dev/null
  yum makecache
  cd "${PROJECT_PATH}"
}

install-app() {
  if rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null && rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "Galera4 cluster already installed!"
    return 0
  fi

  if [[ "1" == "${STOP_SERV_ON_INSTALL}" ]]; then
    ops/run.sh stop
  else
    local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
    if [[ "${service_status}" != "inactive" ]] && [[ "${service_status}" != "dead" ]]; then
      echo "Service mysqld has not been shutdown completed!"
      exit 1
    fi
  fi

  dnf -y module disable mysql mariadb &>/dev/null

  echo "Install ${GALERA_NAME}-${GALERA_VERSION} ..."
  "${YUMINSTALLER_SH_FILE}" -o "-y" "${GALERA_NAME}" "${GALERA_VERSION}"

  echo "Install ${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} ..."
  "${YUMINSTALLER_SH_FILE}" -o "-y" "${MYSQL_WSREP_NAME}" "${MYSQL_WSREP_VERSION}"
}

install-conf() {
  check-clusteraddress
  if ! rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "${GALERA_NAME}-${GALERA_VERSION} has not been installed yet!"
    exit 1
  fi

  if ! rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} has not been installed yet!"
    exit 1
  fi

  "${RENDER_SH_FILE}" conf/my.cnf.tmpl "conf/my.cnf"
  trap 'rm -rf "conf/my.cnf"' EXIT

  install -D -m 644 "conf/my.cnf" "/etc/my.cnf"
}

check-clusteraddress() {
  if [ -z "${MYSQLD_WSREP_CLUSTER_ADDRESS}" ]; then
    echo "MYSQLD_WSREP_CLUSTER_ADDRESS is empty!" >&2
    exit 1
  fi

  IFS=',' read -r -a WSREP_CLUSTER_ADDRESS_ARRAY <<<"${MYSQLD_WSREP_CLUSTER_ADDRESS}"

  if [ "${#WSREP_CLUSTER_ADDRESS_ARRAY[@]}" -lt 2 ]; then
    echo "MYSQLD_WSREP_CLUSTER_ADDRESS is invalid!" >&2
    exit 1
  fi

  WSREP_CLUSTER_ADDRESS_ARRAY=($(printf "%s\n" "${WSREP_CLUSTER_ADDRESS_ARRAY[@]}" | LC_ALL=C sort -s -t '.' -k1,1n -k2,2n -k3,3n -k4,4n))

  local check_hostip_error=$("${CHECKHOSTIP_SH_FILE}" "${MYSQLD_WSREP_NODE_ADDRESS}" 2>&1 || true)
  if [ ! -z "${check_hostip_error}" ]; then
    echo "MYSQLD_WSREP_NODE_ADDRESS: ${MYSQLD_WSREP_NODE_ADDRESS} not matched any host_ip!" >&2
    exit 1
  fi

  MYSQLD_WSREP_NODE_ADDRESS_INDEX="-1"
  for index in "${!WSREP_CLUSTER_ADDRESS_ARRAY[@]}"; do
    if [ "${WSREP_CLUSTER_ADDRESS_ARRAY[$index]}" != "${MYSQLD_WSREP_NODE_ADDRESS}" ]; then
      continue
    fi

    MYSQLD_WSREP_NODE_ADDRESS_INDEX="$index"
    break

  done

  if [[ ${MYSQLD_WSREP_NODE_ADDRESS_INDEX} == "-1" ]]; then
    echo "MYSQLD_WSREP_NODE_ADDRESS: ${MYSQLD_WSREP_NODE_ADDRESS} not matched any MYSQLD_WSREP_CLUSTER_ADDRESS: ${MYSQLD_WSREP_CLUSTER_ADDRESS} !" >&2
    exit 1
  fi
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
