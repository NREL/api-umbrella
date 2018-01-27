# NodeJS: For building admin-ui Ember app.

set(NODEJS_VERSION 6.12.3)
set(NODEJS_HASH 94ebeb5fb0176229bc2ec8b83fe92254facb13041e147aeebad12c72e798aa29)
set(YARN_VERSION 1.4.1)
set(YARN_HASH 058e04214a6c54c859f11d0c5dba414b)

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
