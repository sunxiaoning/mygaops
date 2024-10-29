CLEAN_DATA_ON_UNINSTALL=${CLEAN_DATA_ON_UNINSTALL:-"0"}
STOP_SERV_ON_UNINSTALL=${STOP_SERV_ON_UNINSTALL:-"0"}

uninstall-app() {
  uninstall-galera-rpm

  uninstall-mysql-wsrep-rpm

  clean-mysql-datadir
}

uninstall-galera-rpm() {
  if ! rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "Galera RPM is not exists, skip the operation!"
    return 0
  fi

  check-mysqld-stopped

  # TODO check-safebootstrap, the last commit node should be the last node to be uninstalled.

  yum -y remove "${GALERA_NAME}-${GALERA_VERSION}"

  if rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "Remove Galera RPM failed!" >&2
    exit 1
  fi
}

uninstall-mysql-wsrep-rpm() {
  if ! rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "MySQL-WSREP RPM is not exists, skip the operation!"
    return 0
  fi

  check-mysqld-stopped

  # TODO check-safebootstrap, the last commit node should be the last node to be uninstalled.

  yum -y remove "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}"

  if rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "Remove MySQL-WSREP RPM failed!" >&2
    exit 1
  fi
}

uninstall-galera4-repo() {
  echo "Uninstall galera4 repo..."

  "${RPMREPO_SH_FILE}" uninstall-galera4
}

uninstall-mysql-wsrep8-repo() {
  echo "Uninstall mysql-wsrep8 repo..."

  "${RPMREPO_SH_FILE}" uninstall-mysql-wsrep8
}

uninstall-app-repo() {
  uninstall-galera4-repo
  uninstall-mysql-wsrep8-repo
}

check-mysqld-stopped() {
  if [[ "1" == "${STOP_SERV_ON_UNINSTALL}" ]]; then
    stop
  else
    local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
    if [[ "${service_status}" != "inactive" ]] && [[ "${service_status}" != "dead" ]]; then
      echo "Service mysqld has not been shutdown completed!"
      exit 1
    fi
  fi
}

clean-mysql-datadir() {
  if [[ "1" == "${CLEAN_DATA_ON_UNINSTALL}" ]]; then
    echo "[Warning] Clean old MySQL datadir ..."
    rm -rf ${MYSQLD_DATADIR}
  fi
}
