#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

export DEBUG=${DEBUG:-"0"}

if [[ "${DEBUG}" == "1" ]]; then
  set -x
fi

BOOTSTRAP=${BOOTSTRAP:-"0"}

GALERA_NAME=${GALERA_NAME:-"galera-4"}
GALERA_VERSION=${GALERA_VERSION:-"26.4.19"}

MYSQL_WSREP_NAME=${GALERA_NAME:-"mysql-wsrep-8.0"}
MYSQL_WSREP_VERSION=${GALERA_VERSION:-"8.0.37"}

MYSQLD_DATADIR=/var/lib/mysql

# TODO is safe, var scope ???
NEW_PASSWORD=${NEW_PASSWORD:-""}
NEW_PASSWORD_FILE=${NEW_PASSWORD_FILE:-".dmypasswd.txt"}

if [[ -z "${NEW_PASSWORD}" ]]; then
  echo "NEW_PASSWORD not set, try to load from password file ..."
  if [[ ! -f "${NEW_PASSWORD_FILE}" ]]; then
    echo "Error: NEW_PASSWORD_FILE: ${NEW_PASSWORD_FILE} not found!"
    exit 1
  fi
  NEW_PASSWORD=$(cat "${NEW_PASSWORD_FILE}")
fi

if [[ -z "${NEW_PASSWORD}" ]]; then
  echo "NEW_PASSWORD can't be empty!"
  exit 1
fi

TEMP_PASSWORD=""

TIMEOUT_DURATION="30s"

MYSQL_USER=${MYSQL_USER:-"root"}

# TODO is safe, var scope ???
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"${NEW_PASSWORD}"}
MYSQL_HOST=${MYSQL_HOST:-"localhost"}
MYSQL_PORT=${MYSQL_PORT:-"3306"}

start() {
  if systemctl is-active --quiet mysqld; then
    return 0
  fi

  if ! rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "${GALERA_NAME}-${GALERA_VERSION} has not been installed yet!"
    exit 1
  fi
  if ! rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} has not been installed yet!"
    exit 1
  fi

  setsegalera

  if [[ "1" == "${BOOTSTRAP}" ]]; then
    echo "Bootstrap mysqld ..."
    mysqld_bootstrap
    return 0
  fi

  if ! timeout "${TIMEOUT_DURATION}" systemctl start mysqld; then
    echo "Error: Service mysqld failed to start within ${TIMEOUT_DURATION} or encountered an error."
    exit 1
  fi

  if ! systemctl is-active --quiet mysqld; then
    echo "mysqld is not running!"
    exit 1
  fi
}

init() {

  if [[ "0" == "${BOOTSTRAP}" ]]; then
    echo "BOOTSTRAP false, init abort!"
    exit 1
  fi

  if ! systemctl is-active --quiet mysqld; then
    echo "mysqld is not running!"
    exit 1
  fi

  TEMP_PASSWORD=$(journalctl -u mysqld | grep 'temporary password' | tail -n 1 | awk '{print $NF}')
  if [ -z "${TEMP_PASSWORD}" ]; then
    echo "Error: can't find TEMP_PASSWORD, may be not init success or install log expired, you can run 'reinit' command to reinit mysqld."
    exit 1
  fi
  setpassword
}

reinit() {

  if [[ "0" == "${BOOTSTRAP}" ]]; then
    echo "BOOTSTRAP false, reinit abort!"
    exit 1
  fi

  if ! rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "${GALERA_NAME}-${GALERA_VERSION} has not been installed yet!"
    exit 1
  fi

  if ! rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} has not been installed yet!"
    exit 1
  fi

  if ! id -u mysql &>/dev/null; then
    echo "MySQL user 'mysql' does not exist. Please reinstall MySQL."
    exit 1
  fi

  if ! getent group mysql &>/dev/null; then
    echo "MySQL group 'mysql' does not exist. Please reinstall MySQL."
    exit 1
  fi

  stop

  rm -rf ${MYSQLD_DATADIR}

  mkdir -p /var/log/mysql
  touch /var/log/mysql/error.log
  chown mysql:mysql /var/log/mysql/error.log
  chmod 640 /var/log/mysql/error.log

  local err_log="/var/log/mysql/error.log"
  mysqld --initialize --log-error="${err_log}"

  start

  TEMP_PASSWORD=$(grep 'temporary password' "${err_log}" | tail -n 1 | awk '{print $NF}')
  setpassword
}

setpassword() {
  if [ -z "${TEMP_PASSWORD}" ]; then
    echo "Failed to get temporary password. Assuming password has been changed or login issue."
    exit 1
  fi

  local login_output=$(mysql -u root -p"${TEMP_PASSWORD}" -e "SELECT 1;" 2>&1)
  if echo "${login_output}" | grep -q "ERROR"; then
    echo "[Warning] Failed to login with temporary password. Assuming password has been changed or login issue!"
    return 0
  fi

  local setpass_output=$(mysql -u root -p"${TEMP_PASSWORD}" --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_PASSWORD}';" 2>&1)
  if echo "${setpass_output}" | grep -q "ERROR"; then
    echo "Failed to setpassword: ${setpass_output} !"
    exit 1
  fi
  unset NEW_PASSWORD
  unset TEMP_PASSWORD
}

setsegalera() {
  setsemysqld_t
}

setsemysqld_t() {
  if semanage permissive -l | grep -q mysqld_t; then
    return 0
  fi
  echo "Adding mysqld_t to permissive mode."
  semanage permissive -a mysqld_t
}

stop() {
  local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
  if [[ "${service_status}" == "inactive" ]] || [[ "${service_status}" == "dead" ]]; then
    return 0
  fi

  if ! timeout "${TIMEOUT_DURATION}" systemctl stop mysqld; then
    echo "Error: Service mysqld failed to stop within ${TIMEOUT_DURATION} or encountered an error."
    exit 1
  fi

  service_status=$(systemctl is-active mysqld 2>/dev/null || true)
  if [[ "${service_status}" == "inactive" ]] || [[ "${service_status}" == "dead" ]]; then
    return 0
  fi
  echo "Error: Service mysqld is not stopped properly. Current status: ${service_status}."
  exit 1
}

check-node() {
  # TODO login, SELECT test
  local output=$(mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -e "SHOW STATUS LIKE 'wsrep_%';")
  local cluster_status=$(echo "${output}" | grep "wsrep_cluster_status" | awk '{print $2}')
  if [ "${cluster_status}" != "Primary" ]; then
    echo "Check node status failed! wsrep_cluster_status: ${cluster_status}"m
    exit 1
  fi
  local local_state=$(echo "${output}" | grep -E "wsrep_local_state\s+" | awk '{print $2}')
  local local_state_comment=$(echo "${output}" | grep "wsrep_local_state_comment" | awk '{print $2}')
  echo "wsrep_local_state: ${local_state}, wsrep_local_state_comment: ${local_state_comment}"

  if [ "${local_state}" != "4" ] && [ "${local_state_comment}" != "Synced" ]; then
    echo "Check node status failed! wsrep_local_state: ${local_state}, wsrep_local_state_comment: ${local_state_comment}"
    exit 1
  fi

  local connected=$(echo "${output}" | grep 'wsrep_connected' | awk '{print $2}')
  if [ "${connected}" != "ON" ]; then
    echo "Check node status failed! wsrep_connected: ${connected}"
    exit 1
  fi
  local ready=$(echo "${output}" | grep "wsrep_ready" | awk '{print $2}')
  if [ "${ready}" != "ON" ]; then
    echo "Check node status failed! wsrep_ready: ${ready}"
    exit 1
  fi

  local cluster_size=$(echo "${output}" | grep 'wsrep_cluster_size' | awk '{print $2}')
  if [ "${cluster_size}" -lt "${MYSQLD_WSREP_CLUSTER_SIZE}" ]; then
    echo "Check node ${MYSQLD_WSREP_NODE_ADDRESS} status failed! cluster_size: ${cluster_size}"
    exit 1
  fi
  echo "The node: ${MYSQLD_WSREP_NODE_ADDRESS} of cluster is healthy and operational."
}

main() {
  case "${1-}" in
  start)
    start
    ;;
  init)
    init
    ;;
  check-node)
    check-node
    ;;
  reinit)
    reinit
    ;;
  stop)
    stop
    ;;
  *)
    echo "Action not support! start/stop/restart only!"
    ;;
  esac
}

main "$@"
