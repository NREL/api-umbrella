# NodeJS: For building admin-ui Ember app.
ExternalProject_Add(
  nodejs
  URL https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz
  URL_HASH SHA256=${NODEJS_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v <SOURCE_DIR>/ ${DEV_INSTALL_PREFIX}/
)

ExternalProject_Add(
  yarn
  DEPENDS nodejs
  URL https://github.com/yarnpkg/yarn/releases/download/v${YARN_VERSION}/yarn-v${YARN_VERSION}.tar.gz
  URL_HASH MD5=${YARN_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v --delete <SOURCE_DIR>/ ${DEV_INSTALL_PREFIX}/yarn/
    # Remove the previous bin symlink that was necessary.
    COMMAND rm -f ${DEV_INSTALL_PREFIX}/bin/yarn.js
)
