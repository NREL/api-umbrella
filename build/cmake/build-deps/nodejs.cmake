# NodeJS: For building admin-ui Ember app.

set(NODEJS_VERSION 8.11.2)
set(NODEJS_HASH 213599127d24496cbf1cbb2a7c51060a3506d6b11132c59bb7f9f8a0edd210a7)
set(YARN_VERSION 1.6.0)
set(YARN_HASH a11a3d8a5d62712fc497a6d1cbea25f6)

ExternalProject_Add(
  nodejs
  EXCLUDE_FROM_ALL 1
  URL https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz
  URL_HASH SHA256=${NODEJS_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v <SOURCE_DIR>/ ${DEV_INSTALL_PREFIX}/
)

ExternalProject_Add(
  yarn
  EXCLUDE_FROM_ALL 1
  DEPENDS nodejs
  URL https://github.com/yarnpkg/yarn/releases/download/v${YARN_VERSION}/yarn-v${YARN_VERSION}.tar.gz
  URL_HASH MD5=${YARN_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v --delete <SOURCE_DIR>/ ${DEV_INSTALL_PREFIX}/yarn/
    COMMAND cd ${DEV_INSTALL_PREFIX}/bin && ln -snf ../yarn/bin/yarn ./yarn
    # Remove the previous bin symlink that was necessary.
    COMMAND rm -f ${DEV_INSTALL_PREFIX}/bin/yarn.js
)
