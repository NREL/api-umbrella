# NodeJS: For building admin-ui Ember app.
ExternalProject_Add(
  nodejs_test
  URL https://nodejs.org/dist/v${NODEJS_TEST_VERSION}/node-v${NODEJS_TEST_VERSION}-linux-x64.tar.xz
  URL_HASH SHA256=${NODEJS_TEST_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v <SOURCE_DIR>/ ${TEST_INSTALL_PREFIX}/
)
