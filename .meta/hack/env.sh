set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"

PKG_VERSION="1.1.5"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
## Improvements
- Optimized the \'init\' function to ensure idempotent operations.
- Improved the \'reinit\' function to prevent unsafe operations.
- Refined the \'stop\' function to include \'reset-failed\' before execution.
- Enhanced the \'WSREP_CLUSTER_ADDRESS_ARRAY\' environment variable to maintain an idempotent sequence.
- Refined various check logic to ensure function robustness.

## Bug Fixes
- Fixed an issue with the \'execrsh.sh\' script where the \'SSH_OPTIONS\' environment variable was not applied correctly.
"
