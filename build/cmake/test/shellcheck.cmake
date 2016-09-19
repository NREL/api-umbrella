ExternalProject_Add(
  shellcheck
  URL https://github.com/caarlos0/shellcheck-docker/releases/download/v${SHELLCHECK_VERSION}/shellcheck
  URL_HASH MD5=${SHELLCHECK_HASH}
  DOWNLOAD_NAME shellcheck-binz
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <DOWNLOADED_FILE> ${TEST_INSTALL_PREFIX}/bin/shellcheck
)
