#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename "$0")

TERMINATE_DONE=0
CLEAN_DONE=0

trap __terminate INT TERM
trap __cleanup EXIT

. ${SCRIPT_DIR}/env.sh

. ${SCRIPT_DIR}/basegrastate.sh

BOOTSTRAP=${BOOTSTRAP:-"0"}
EXECRSH_SH_FILE="${SCRIPT_DIR}/../bashutils/execrsh.sh"

# TODO is safe, var scope ???
NEW_PASSWORD=${NEW_PASSWORD:-""}
HOME_DIR=$(__get-original-home-dir)
DEFAULT_NEW_PASSWORD_DIR="${HOME_DIR}/.mygaops"
DEFAULT_NEW_PASSWORD_FILE="${DEFAULT_NEW_PASSWORD_DIR}/.dmypasswd.txt"
NEW_PASSWORD_FILE=${NEW_PASSWORD_FILE:-"${DEFAULT_NEW_PASSWORD_FILE}"}

# TODO version controllf
PWGEN_VERSION="2.08"

YUMINSTALLER_SH_FILE="${SCRIPT_DIR}/../bashutils/yuminstaller.sh"

MYSQL_ADMIN_USER="root"
MYSQL_ADMIN_PASSWORD=${MYSQL_ADMIN_PASSWORD:-""}
MYSQL_ADMIN_PASSWORD_FILE=${MYSQL_ADMIN_PASSWORD:-"${NEW_PASSWORD_FILE}"}

MYSQLDOP_TIMEOUT_DURATION=${MYSQLDOP_TIMEOUT_DURATION:-"60s"}

MYSQL_USER=${MYSQL_USER:-"root"}

# TODO is safe, var scope ???
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"${NEW_PASSWORD}"}
MYSQL_PASSWORD_FILE=${MYSQL_PASSWORD_FILE:-"${NEW_PASSWORD_FILE}"}

MYSQL_HOST=${MYSQL_HOST:-"localhost"}
MYSQL_PORT=${MYSQL_PORT:-"3306"}

MYSQLD_WSREP_NODE_ADDRESS=${MYSQLD_WSREP_NODE_ADDRESS:-""}
CHECKHOSTIP_SH_FILE="${SCRIPT_DIR}/../bashutils/checkhostip.sh"

MYSQLD_WSREP_CLUSTER_SIZE=${MYSQLD_WSREP_CLUSTER_SIZE:-""}

MYSQLD_WSREP_CLUSTER_ADDRESS=${MYSQLD_WSREP_CLUSTER_ADDRESS:-""}
WSREP_CLUSTER_ADDRESS_ARRAY=()

TEMP_FILES=()

start() {
  check-clusteraddress

  check-bootstrap

  if ! rpm -q "${GALERA_NAME}-${GALERA_VERSION}" &>/dev/null; then
    echo "${GALERA_NAME}-${GALERA_VERSION} has not been installed yet!" >&2
    exit 1
  fi

  if ! rpm -q "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION}" &>/dev/null; then
    echo "${MYSQL_WSREP_NAME}-${MYSQL_WSREP_VERSION} has not been installed yet!" >&2
    exit 1
  fi

  if systemctl is-active --quiet mysqld; then
    echo "Service mysqld is already started!" >&2
    return 0
  fi

  setsegalera

  reset-failed

  if [[ "1" == "${BOOTSTRAP}" ]]; then
    check-safe-bootstrap

    echo "Bootstrap mysqld ..."
    if ! timeout "${MYSQLDOP_TIMEOUT_DURATION}" mysqld_bootstrap; then
      echo "Error: Service mysqld failed to bootstrap within ${MYSQLDOP_TIMEOUT_DURATION} or encountered an error." >&2
      exit 1
    fi
  else
    if ! timeout "${MYSQLDOP_TIMEOUT_DURATION}" systemctl start mysqld; then
      echo "Error: Service mysqld failed to start within ${MYSQLDOP_TIMEOUT_DURATION} or encountered an error." >&2
      exit 1
    fi
  fi

  if ! systemctl is-active --quiet mysqld; then
    echo "Error: Service mysqld is not running!" >&2
    exit 1
  fi
}

init() {
  check-bootstrap

  if [[ "1" != "${BOOTSTRAP}" ]]; then
    echo "BOOTSTRAP is not true, init abort!"
    exit 1
  fi

  if ! systemctl is-active --quiet mysqld; then
    echo "mysqld is not running!"
    exit 1
  fi

  local temp_password=$(journalctl -u mysqld | grep 'temporary password' | tail -n 1 | awk '{print $NF}')
  if [ -z "${temp_password}" ]; then
    echo "Error: can't find temp_password, may be not init success or install log expired, you can run 'reinit' command to reinit mysqld."
    exit 1
  fi

  if ! check-init-status; then
    echo "Connection with temp_password failed, MySQL has likely been initialized. Skipping initialization."
    return 0
  fi

  MYSQL_ADMIN_PASSWORD="${temp_password}"

  parse-newpassword
  if [[ -z "${NEW_PASSWORD}" ]]; then
    gen-newpassword
  fi

  setpassword
}

check-init-status() {
  local output=$(mysql -u "${MYSQL_ADMIN_USER}" -p"${temp_password}" --connect-expired-password -e "SELECT 1;" 2>&1)
  if [[ "$output" == *"ERROR 1045"* ]]; then
    return 1
  fi

  if [[ "$output" == *"Access denied"* ]]; then
    return 1
  fi

  return 0
}

check-bootstrap() {
  case "${BOOTSTRAP}" in
  0) ;;
  1) ;;
  *)
    echo "Unknown BOOTSTRAP: ${BOOTSTRAP}!"
    exit 1
    ;;
  esac
}

check-safe-bootstrap() {
  if [ ! -d "${MYSQLD_DATADIR}" ]; then
    echo "MySQL installation status abnormal: Directory ${MYSQLD_DATADIR} does not exist." >&2
    exit 1
  fi

  if [[ ! -f "${EXECRSH_SH_FILE}" ]]; then
    echo "Error: require ${EXECRSH_SH_FILE}, but not found!" >&2
    exit 1
  fi

  local safe_to_bootstrap
  safe_to_bootstrap=$(check-galera-safebootstrap)

  if [ -z "${safe_to_bootstrap}" ]; then

    for index in "${!WSREP_CLUSTER_ADDRESS_ARRAY[@]}"; do
      local node_address=${WSREP_CLUSTER_ADDRESS_ARRAY[$index]}
      if [[ "${node_address}" == "${MYSQLD_WSREP_NODE_ADDRESS}" ]]; then
        continue
      fi

      echo "Start checking node: ${node_address} grastate..."

      local tmp_file_node_seqno
      tmp_file_node_seqno=$(mktemp -t node_seqno-XXXXXX)

      TEMP_FILES+=("${tmp_file_node_seqno}")

      "${EXECRSH_SH_FILE}" -e "-o BatchMode=yes" -p "${SCRIPT_DIR}/../bashutils/ ${SCRIPT_DIR}/../hack/" -a "check-seqno" -r "${tmp_file_node_seqno}" "${node_address}" "hack/grastate.sh"

      local node_seqno
      node_seqno=$(cat "${tmp_file_node_seqno}")

      if [[ -z "${node_seqno-}" ]]; then
        continue
      fi

      if [[ "${node_seqno}" == *"Error:"* ]]; then
        echo "check node_seqno failed, ${node_seqno}."
        exit 1
      fi

      if [[ -n "${node_seqno}" ]]; then
        echo "Error: Galera cluster state is inconsistent, abort operation. node_seqno: ${node_seqno}" >&2
        exit 1
      fi

    done

    return 0
  fi

  if [ "${safe_to_bootstrap}" -ne 1 ]; then
    echo "[Warning] Bootstrap status abnormal: safe_to_bootstrap=${safe_to_bootstrap}.Bootstrap operation is being skipped."
    echo "[Warning] Please try to start MySQL directly.If you really need to bootstrap this node, modify safe_to_bootstrap=1 in ${GRSTATE_FILE}, but this is risky, please ensure this node is the most up-to-date and check all nodes before proceeding!"
    exit 1
  fi

  local seqno
  seqno=$(check-galera-seqno)

  if [ -z "${seqno}" ]; then
    echo "MySQL state file abnormal: Missing required fields in ${GRSTATE_FILE}." >&2
    exit 1
  fi

  for index in "${!WSREP_CLUSTER_ADDRESS_ARRAY[@]}"; do
    local node_address=${WSREP_CLUSTER_ADDRESS_ARRAY[$index]}
    if [[ "${node_address}" == "${MYSQLD_WSREP_NODE_ADDRESS}" ]]; then
      continue
    fi

    echo "Start checking node: ${node_address} grastate..."

    local tmp_file_node_seqno
    tmp_file_node_seqno=$(mktemp -t node_seqno-XXXXXX)

    TEMP_FILES+=("${tmp_file_node_seqno}")

    "${EXECRSH_SH_FILE}" -e "-o BatchMode=yes" -p "${SCRIPT_DIR}/../bashutils/ ${SCRIPT_DIR}/../hack/" -a "check-seqno" -r "${tmp_file_node_seqno}" "${node_address}" "hack/grastate.sh"

    local node_seqno
    node_seqno=$(cat "${tmp_file_node_seqno}")

    if [[ -z "${node_seqno-}" ]]; then
      continue
    fi

    if [[ "${node_seqno}" == *"Error:"* ]]; then
      echo "check node_seqno failed, ${node_seqno}."
      exit 1
    fi

    echo "Comparing seqno with node: ${node_address} ..."

    if [[ "${node_seqno}" -gt "${seqno}" ]]; then
      echo "Error: ${MYSQLD_WSREP_NODE_ADDRESS} is not the most recent commit, abort operation." >&2
      exit 1
    fi
  done
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

reinit() {
  check-bootstrap
  if [[ "0" == "${BOOTSTRAP}" ]]; then
    echo "BOOTSTRAP false, reinit abort!"
    exit 1
  fi

  # TODO find the most update node

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

  echo "Stopping service mysqld..."
  stop

  echo "Cleaning MySQL datadir..."
  rm -rf ${MYSQLD_DATADIR}

  echo "Initializing service mysqld..."
  mkdir -p /var/log/mysql
  touch /var/log/mysql/error.log
  chown mysql:mysql /var/log/mysql/error.log
  chmod 640 /var/log/mysql/error.log

  local err_log="/var/log/mysql/error.log"
  mysqld --initialize --log-error="${err_log}"

  echo "Starting service mysqld..."
  start

  echo "Searching MySQL temp password..."
  local temp_password=$(grep 'temporary password' "${err_log}" | tail -n 1 | awk '{print $NF}')
  if [ -z "${temp_password}" ]; then
    echo "Error: can't find temp_password, may be not init success! you can run 'reinit' command again to reinit mysqld." >&2
    exit 1
  fi
  MYSQL_ADMIN_PASSWORD="${temp_password}"

  echo "Resetting MySQL password..."
  parse-newpassword
  if [[ -z "${NEW_PASSWORD}" ]]; then
    gen-newpassword
  fi

  setpassword

  echo "Already reinitialized." >>"${MYSQLD_DATADIR}/.initialized"
}

setpassword() {
  check-bootstrap

  # TODO check is the first node of cluster

  if [[ "1" != "${BOOTSTRAP}" ]]; then
    echo "BOOTSTRAP is not true, setpassword abort!"
    exit 1
  fi

  check-mysql-admin-password

  check-newpassword

  if ! systemctl is-active --quiet mysqld; then
    echo "mysqld is not running!"
    exit 1
  fi

  local setpass_output=$(mysql -u "${MYSQL_ADMIN_USER}" -p"${MYSQL_ADMIN_PASSWORD}" --connect-expired-password -e "ALTER USER '${MYSQL_ADMIN_USER}'@'localhost' IDENTIFIED BY '${NEW_PASSWORD}';" 2>&1)
  if echo "${setpass_output}" | grep -q "ERROR"; then
    echo "Failed to setpassword: ${setpass_output} !"
    exit 1
  fi
  unset NEW_PASSWORD
  unset MYSQL_ADMIN_PASSWORD
}

check-mysql-admin-password() {
  if [[ -z "${MYSQL_ADMIN_PASSWORD}" ]]; then
    echo "MYSQL_ADMIN_PASSWORD not set, try to load from password file ..."
    if [[ ! -f "${MYSQL_ADMIN_PASSWORD_FILE}" ]]; then
      echo "Error: MYSQL_ADMIN_PASSWORD_FILE: ${MYSQL_ADMIN_PASSWORD_FILE} not found!" >&2
      exit 1
    fi
    MYSQL_ADMIN_PASSWORD=$(cat "${MYSQL_ADMIN_PASSWORD_FILE}")
  fi

  if [[ -z "${MYSQL_ADMIN_PASSWORD}" ]]; then
    echo "MYSQL_PASSWORD can't be empty!"
    exit 1
  fi
}

gen-newpassword() {
  if [[ ! -f "${YUMINSTALLER_SH_FILE}" ]]; then
    echo "Error: require ${YUMINSTALLER_SH_FILE}, but not found!" >&2
    return 1
  fi
  "${YUMINSTALLER_SH_FILE}" -o "--enablerepo=epel -y" pwgen "${PWGEN_VERSION}"
  local new_password="$(pwgen -cns 16 1 | sed 's/./!/9')"
  mkdir -p "${DEFAULT_NEW_PASSWORD_DIR}"
  echo "${new_password}" >"${DEFAULT_NEW_PASSWORD_FILE}"
  NEW_PASSWORD="${new_password}"
  echo "Generate MySQL password to file: ${DEFAULT_NEW_PASSWORD_FILE}."
}

check-newpassword() {
  parse-newpassword

  if [[ -z "${NEW_PASSWORD}" ]]; then
    echo "parse NEW_PASSWORD from NEW_PASSWORD env, NEW_PASSWORD_FILE: ${NEW_PASSWORD_FILE} failed!" >&2
    exit 1
  fi
}

parse-newpassword() {
  if [[ -z "${NEW_PASSWORD}" ]]; then
    if [[ -f "${NEW_PASSWORD_FILE}" ]]; then
      NEW_PASSWORD=$(cat "${NEW_PASSWORD_FILE}")
    fi
  fi
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

reset-failed() {
  systemctl reset-failed mysqld
}

stop() {
  local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
  if [[ "${service_status}" == "inactive" ]] || [[ "${service_status}" == "dead" ]]; then
    return 0
  fi

  if ! timeout "${MYSQLDOP_TIMEOUT_DURATION}" systemctl stop mysqld; then
    echo "Error: Service mysqld failed to stop within ${MYSQLDOP_TIMEOUT_DURATION} or encountered an error."
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
  MYSQLD_WSREP_CLUSTER_SIZE=""
  check-nodestatus
}

check-cluster() {
  if [[ -z "${MYSQLD_WSREP_CLUSTER_SIZE}" ]]; then
    echo "MYSQLD_WSREP_CLUSTER_SIZE param is invalid!" >&2
    exit 1
  fi
  check-nodestatus
}

check-nodestatus() {
  if [[ -z "${MYSQLD_WSREP_NODE_ADDRESS}" ]]; then
    echo "MYSQLD_WSREP_NODE_ADDRESS param is invalid!" >&2
    exit 1
  fi

  local check_host_ip_error=$("${CHECKHOSTIP_SH_FILE}" "${MYSQLD_WSREP_NODE_ADDRESS}" 2>&1 || true)
  if [ ! -z "${check_host_ip_error}" ]; then
    echo "MYSQLD_WSREP_NODE_ADDRESS: ${MYSQLD_WSREP_NODE_ADDRESS} not matched any host_ip!" >&2
    exit 1
  fi

  if [[ -z "${MYSQL_USER}" ]]; then
    echo "MYSQL_USER param is invalid!" >&2
    exit 1
  fi

  if [[ -z "${MYSQL_HOST}" ]]; then
    echo "MYSQL_HOST param is invalid!" >&2
    exit 1
  fi

  if [[ -z "${MYSQL_PORT}" ]]; then
    echo "MYSQL_PORT param is invalid!" >&2
    exit 1
  fi

  check-mysqlpassword

  # TODO login, SELECT test

  local output=$(mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -e "SHOW STATUS LIKE 'wsrep_%';")
  local cluster_status=$(echo "${output}" | grep "wsrep_cluster_status" | awk '{print $2}')
  if [ "${cluster_status}" != "Primary" ]; then
    echo "Check node: ${MYSQLD_WSREP_NODE_ADDRESS}  status failed! wsrep_cluster_status: ${cluster_status}" >&2
    exit 1
  fi

  local local_state=$(echo "${output}" | grep -E "wsrep_local_state\s+" | awk '{print $2}')
  local local_state_comment=$(echo "${output}" | grep "wsrep_local_state_comment" | awk '{print $2}')

  if [ "${local_state}" != "4" ] && [ "${local_state_comment}" != "Synced" ]; then
    echo "Check node: ${MYSQLD_WSREP_NODE_ADDRESS} status failed! wsrep_local_state: ${local_state}, wsrep_local_state_comment: ${local_state_comment}" >&2
    exit 1
  fi

  local connected=$(echo "${output}" | grep 'wsrep_connected' | awk '{print $2}')
  if [ "${connected}" != "ON" ]; then
    echo "Check node: ${MYSQLD_WSREP_NODE_ADDRESS} status failed! wsrep_connected: ${connected}" >&2
    exit 1
  fi
  local ready=$(echo "${output}" | grep "wsrep_ready" | awk '{print $2}')
  if [ "${ready}" != "ON" ]; then
    echo "Check node: ${MYSQLD_WSREP_NODE_ADDRESS} status failed! wsrep_ready: ${ready}" >&2
    exit 1
  fi

  if [[ -z "${MYSQLD_WSREP_CLUSTER_SIZE}" ]]; then
    echo "The node: ${MYSQLD_WSREP_NODE_ADDRESS} of cluster is healthy and operational."
    return 0
  fi

  local cluster_size=$(echo "${output}" | grep 'wsrep_cluster_size' | awk '{print $2}')
  echo "MYSQLD_WSREP_CLUSTER_SIZE: ${MYSQLD_WSREP_CLUSTER_SIZE}"
  if [ "${cluster_size}" -ne "${MYSQLD_WSREP_CLUSTER_SIZE}" ]; then
    echo "Check node: ${MYSQLD_WSREP_NODE_ADDRESS} status failed! wsrep_cluster_size: ${cluster_size}" >&2
    exit 1
  fi
  echo "The cluster on node: ${MYSQLD_WSREP_NODE_ADDRESS} is healthy and operational."
}

check-mysqlpassword() {
  if [[ -z "${MYSQL_PASSWORD}" ]]; then
    echo "MYSQL_PASSWORD not set, try to load from password file ..."
    if [[ ! -f "${MYSQL_PASSWORD_FILE}" ]]; then
      echo "Error: MYSQL_PASSWORD_FILE: ${MYSQL_PASSWORD_FILE} not found!" >&2
      exit 1
    fi
    MYSQL_PASSWORD=$(cat "${MYSQL_PASSWORD_FILE}")
  fi

  if [[ -z "${MYSQL_PASSWORD}" ]]; then
    echo "MYSQL_PASSWORD can't be empty!"
    exit 1
  fi
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
  check-cluster)
    check-cluster
    ;;
  reinit)
    reinit
    ;;
  reset-password)
    setpassword
    ;;
  stop)
    stop
    ;;
  *)
    echo "Action not support! start/stop/restart only!"
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
