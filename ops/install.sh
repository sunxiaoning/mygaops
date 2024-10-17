RPMREPO_SH_FILE="${CONTEXT_DIR}/rpmrepo/rpmrepo.sh"

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
export MYSQLD_WSREP_CLUSTER_ADDRESS
export MYSQLD_WSREP_NODE_NAME=${MYSQLD_WSREP_NODE_NAME:-$(hostname)}
export MYSQLD_WSREP_NODE_ADDRESS

STOP_SERV_ON_INSTALL=${STOP_SERV_ON_INSTALL:-"0"}

RENDER_SH_FILE="${CONTEXT_DIR}/bashutils/render.sh"

install-repo() {
  "${RPMREPO_SH_FILE}" install-galera4
}

install-app() {
  install-repo

  install-galera-rpm
  install-mysql-wsrep-rpm
}

install-galera-rpm() {
  if rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "Galera RPM is already installed!"
    return 0
  fi

  check-mysqld-stopped

  dnf -y module disable mysql mariadb >/dev/null

  echo "Install ${GALERA_NAME}-${GALERA_VERSION} ..."
  "${YUMINSTALLER_SH_FILE}" -o "-y" "${GALERA_NAME}" "${GALERA_VERSION}"
}

install-mysql-wsrep-rpm() {
  if rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "MySQL RPM is already installed!"
    return 0
  fi

  check-mysqld-stopped

  dnf -y module disable mysql mariadb >/dev/null

  echo "Install ${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} ..."
  "${YUMINSTALLER_SH_FILE}" -o "-y" "${MYSQL_WSREP_NAME}" "${MYSQL_WSREP_VERSION}"
}

check-mysqld-stopped() {
  if [[ "1" == "${STOP_SERV_ON_INSTALL}" ]]; then
    stop
  else
    local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
    if [[ "${service_status}" != "inactive" ]] && [[ "${service_status}" != "dead" ]]; then
      echo "Service mysqld has not been shutdown completed!"
      exit 1
    fi
  fi
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

  "${RENDER_SH_FILE}" "${CONTEXT_DIR}/conf/my.cnf.tmpl" "${CONTEXT_DIR}/conf/my.cnf"

  TEMP_FILES+=("${CONTEXT_DIR}/conf/my.cnf")

  install -D -m 644 "${CONTEXT_DIR}/conf/my.cnf" "/etc/my.cnf"
}
