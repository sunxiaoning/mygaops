. ${SCRIPT_DIR}/../bashutils/basicenv.sh

USE_DOCKER=${USE_DOCKER:-"0"}

GALERA_NAME=${GALERA_NAME:-"galera-4"}
GALERA_VERSION=${GALERA_VERSION:-"26.4.19"}

MYSQL_WSREP_NAME=${MYSQL_WSREP_NAME:-"mysql-wsrep-8.0"}
MYSQL_WSREP_VERSION=${MYSQL_WSREP_VERSION:-"8.0.37"}

MYSQLD_DATADIR=/var/lib/mysql
