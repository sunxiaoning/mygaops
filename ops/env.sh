GALERA_NAME=${GALERA_NAME:-"galera-4"}
GALERA_VERSION=${GALERA_VERSION:-"26.4.20"}

MYSQL_WSREP_NAME=${MYSQL_WSREP_NAME:-"mysql-wsrep-8.0"}
MYSQL_WSREP_VERSION=${MYSQL_WSREP_VERSION:-"8.0.39"}

MYSQLD_DATADIR=/var/lib/mysql

MYSQLD_WSREP_NODE_ADDRESS=${MYSQLD_WSREP_NODE_ADDRESS:-$(hostname -I | awk '{print $1}')}

MYSQLD_WSREP_CLUSTER_ADDRESS=${MYSQLD_WSREP_CLUSTER_ADDRESS:-""}

YUMINSTALLER_SH_FILE="${CONTEXT_DIR}/bashutils/yuminstaller.sh"

CHECKHOSTIP_SH_FILE="${CONTEXT_DIR}/bashutils/checkhostip.sh"

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

  if [[ -z "${MYSQLD_WSREP_NODE_ADDRESS}" ]]; then
    echo "MYSQLD_WSREP_NODE_ADDRESS param is invalid!" >&2
    exit 1
  fi

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
