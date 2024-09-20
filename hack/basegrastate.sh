GRSTATE_FILE="${MYSQLD_DATADIR}/grastate.dat"

parse-galera-safebootstrap() {
  if [ ! -f "${GRSTATE_FILE}" ] || [ ! -s "${GRSTATE_FILE}" ]; then
    echo ""
    return 0
  fi
  local safe_to_bootstrap=$(grep "^safe_to_bootstrap:" "${GRSTATE_FILE}" | awk '{print $2}')

  if [ -z "${safe_to_bootstrap}" ]; then
    echo "MySQL state file abnormal: Missing required fields in ${GRSTATE_FILE}." >&2
    return 1
  fi
  echo "${safe_to_bootstrap}"
}

parse-galera-seqno() {
  if [ ! -f "${GRSTATE_FILE}" ] || [ ! -s "${GRSTATE_FILE}" ]; then
    echo ""
    return 0
  fi
  local seqno=$(grep "^seqno:" "${GRSTATE_FILE}" | awk '{print $2}')
  if [ -z "${seqno}" ]; then
    echo "MySQL state file abnormal: Missing required fields in ${GRSTATE_FILE}." >&2
    return 1
  fi
  echo "${seqno}"
}

check-galera-mysqld-stopped() {
  local service_status=$(systemctl is-active mysqld 2>/dev/null || true)
  if [[ "${service_status}" == "inactive" ]] || [[ "${service_status}" == "dead" ]]; then
    return 0
  fi
  return 1
}

check-galera-safebootstrap() {
  if ! check-galera-mysqld-stopped; then
    echo "Error: mysqld is not stopped, abort operation." >&2
    return 1
  fi
  parse-galera-safebootstrap
}

check-galera-seqno() {
  if ! check-galera-mysqld-stopped; then
    echo "Error: mysqld is not stopped, abort operation." >&2
    return 1
  fi
  parse-galera-seqno
}
