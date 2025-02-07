. ${OPS_SH_DIR}/basegrastate.sh

BOOTSTRAP=${BOOTSTRAP:-"0"}

# TODO is safe, var scope ???
NEW_PASSWORD=${NEW_PASSWORD:-""}
HOME_DIR=$(__get-original-home-dir)
DEFAULT_NEW_PASSWORD_DIR="${HOME_DIR}/.mygaops"
DEFAULT_NEW_PASSWORD_FILE="${DEFAULT_NEW_PASSWORD_DIR}/.dmypasswd.txt"
NEW_PASSWORD_FILE=${NEW_PASSWORD_FILE:-"${DEFAULT_NEW_PASSWORD_FILE}"}

# TODO version controllf
PWGEN_VERSION="2.08"

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

MYSQLD_WSREP_CLUSTER_SIZE=${MYSQLD_WSREP_CLUSTER_SIZE:-""}

WSREP_CLUSTER_ADDRESS_ARRAY=()

start() {
  check-bootstrap

  if [[ -z "${MYSQLD_WSREP_NODE_ADDRESS}" ]]; then
    echo "MYSQLD_WSREP_NODE_ADDRESS param is invalid!" >&2
    exit 1
  fi

  check-clusteraddress

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

  # A new node can choose to boostrap a new cluster, or joinning an exists cluster.
  if [[ "1" == "${BOOTSTRAP}" ]]; then
    echo "Checking safe-boostrap..."
    check-safe-bootstrap

    echo "Bootstrap mysqld ..."
    if ! timeout "${MYSQLDOP_TIMEOUT_DURATION}" mysqld_bootstrap; then
      echo "Error: Service mysqld failed to bootstrap within ${MYSQLDOP_TIMEOUT_DURATION} or encountered an error." >&2
      exit 1
    fi
  else
    echo "Start mysqld..."
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

init-server() {

  if ! systemctl is-active --quiet mysqld; then
    echo "Service mysqld is not running!"
    exit 1
  fi

  local temp_password=$(journalctl -u mysqld | grep 'temporary password' | tail -n 1 | awk '{print $NF}')
  if [ -z "${temp_password}" ]; then
    echo "[Warning] Temporary password not found. Potential reasons include: failed initialization, expired logs, or initialization may have already been performed on another node. If initialization failed, consider using the 'reinit-server' command to reinitialize MySQL."
    return 0
  fi

  MYSQL_ADMIN_PASSWORD="${temp_password}"

  if ! check-init-status; then
    echo "[Warning] Unable to connect using the temporary password. MySQL may have already been initialized. Skipping initialization."
    return 0
  fi

  parse-newpassword
  if [[ -z "${NEW_PASSWORD}" ]]; then
    gen-newpassword
  fi

  reset-password
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

check-init-status() {
  local output=$(mysql -u "${MYSQL_ADMIN_USER}" -p"${MYSQL_ADMIN_PASSWORD}" --connect-expired-password -e "SELECT 1;" 2>&1)
  if [[ "$output" == *"ERROR 1045"* ]]; then
    return 1
  fi

  if [[ "$output" == *"Access denied"* ]]; then
    return 1
  fi

  return 0
}

# can't ensure grastate is completely correct, but try the best efforts.
# but galera cluster will be the last line to abort abnormal status.
check-safe-bootstrap() {
  if [[ -z "${MYSQLD_WSREP_NODE_ADDRESS}" ]]; then
    echo "MYSQLD_WSREP_NODE_ADDRESS param is invalid!" >&2
    exit 1
  fi

  check-clusteraddress

  if [ ! -d "${MYSQLD_DATADIR}" ]; then
    echo "MySQL installation status abnormal: Directory ${MYSQLD_DATADIR} does not exist." >&2
    exit 1
  fi

  echo "Start checking current node: ${MYSQLD_WSREP_NODE_ADDRESS} grastate..."

  stop

  local safe_to_bootstrap=$(check-galera-safebootstrap | grep "^result-galera-safebootstrap: " | awk '{print $2}' || true)

  if [ -z "${safe_to_bootstrap-}" ]; then
    echo "[Warning] check-galera-safebootstrap failed! safe_to_bootstrap is unknown."
    return 0
  fi

  if [ "${safe_to_bootstrap}" -ne 1 ]; then
    echo "Error: Bootstrap status abnormal: safe_to_bootstrap=${safe_to_bootstrap}." >&2
    echo "[Warning] Please try to start MySQL directly.If you really need to bootstrap this node, modify safe_to_bootstrap=1 in ${GRSTATE_FILE}, but this is risky, please ensure this node is the most up-to-date and check all nodes before proceeding!"
    exit 1
  fi
}

reinit-server() {
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

  echo "Checking safe-bootstrap ..."
  local error_bootstrap=$(check-safe-bootstrap 2>&1 >/dev/null | tee /dev/stderr)
  if [[ -n "${error_bootstrap-}" ]]; then
    echo "Error: check-safe-bootstrap failed, abort the operation." >&2
    exit 1
  fi

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
    echo "Error: Temporary password not found. Potential reasons include: failed initialization, expired logs, or initialization may have already been performed on another node. If initialization failed, consider using the 'reinit-server' command to reinitialize MySQL."
    exit 1
  fi
  MYSQL_ADMIN_PASSWORD="${temp_password}"

  echo "Resetting MySQL password..."
  parse-newpassword
  if [[ -z "${NEW_PASSWORD}" ]]; then
    gen-newpassword
  fi

  reset-password
}

reset-password() {

  check-mysql-admin-password

  check-newpassword

  if ! systemctl is-active --quiet mysqld; then
    echo "mysqld is not running!"
    exit 1
  fi

  local setpass_output=$(mysql -u "${MYSQL_ADMIN_USER}" -p"${MYSQL_ADMIN_PASSWORD}" --connect-expired-password -e "ALTER USER '${MYSQL_ADMIN_USER}'@'localhost' IDENTIFIED BY '${NEW_PASSWORD}';" 2>&1)
  if echo "${setpass_output}" | grep -q "ERROR"; then
    echo "Failed to reset-password: ${setpass_output} !"
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

  if ! rpm -q "epel-release" &>/dev/null; then
    yum -y install epel-release
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/epel.repo
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
  status=$(sestatus | grep 'SELinux status' | awk '{print $3}')
  if [ "$status" == "disabled" ]; then
    echo "SELinux is disabled, skip setsemysqld_t."
    return 0
  fi
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

  reset-failed

  if ! timeout "${MYSQLDOP_TIMEOUT_DURATION}" systemctl stop mysqld; then
    echo "Error: Service mysqld failed to stop within ${MYSQLDOP_TIMEOUT_DURATION} or encountered an error." >&2
    exit 1
  fi

  service_status=$(systemctl is-active mysqld 2>/dev/null || true)
  if [[ "${service_status}" == "inactive" ]] || [[ "${service_status}" == "dead" ]]; then
    return 0
  fi
  echo "Error: Service mysqld is not stopped properly. Current status: ${service_status}." >&2
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
