set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

GALERA_NAME=${GALERA_NAME:-"galera-4"}
GALERA_VERSION=${GALERA_VERSION:-"26.4.19"}

MYSQL_WSREP_NAME=${GALERA_NAME:-"mysql-wsrep-8.0"}
MYSQL_WSREP_VERSION=${GALERA_VERSION:-"8.0.37"}

MYSQLD_DATADIR=/var/lib/mysql