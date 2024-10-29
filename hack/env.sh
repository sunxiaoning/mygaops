set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH="hack/pack"

PKG_VERSION="1.1.16"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
- Optimized the install-app logic for improved clarity and efficiency.
- Added support for the uninstall-repo process to enhance functionality.
"
