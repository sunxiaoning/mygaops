set -o nounset
set -o errexit
set -o pipefail

USE_DOCKER=${USE_DOCKER:-"0"}

PKG_PATH=".meta/hack/pack"

PKG_VERSION="1.1.3"
PKG_NAME="mygaops-${PKG_VERSION}.tar.gz"

REL_TAG="v${PKG_VERSION}"
REL_TITLE="Release v${PKG_VERSION}"
REL_NOTES="
## Release v1.2.0 (2024-09-20)

## New Features
- **Added** $(basicenv.sh): Provides common environment variables and functions.
- **Improved** $(execrsh.sh): Now supports passing parameters to Bash scripts.

## Bug Fixes
- Fixed an issue where $(make) commands were not executed in sequence, preventing race conditions during builds.

For more information, please refer to the [documentation](https://example.com/docs).
"
