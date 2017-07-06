ExternalProject_Add(
  shellcheck
  URL https://storage.googleapis.com/shellcheck/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz
  URL_HASH SHA512=${SHELLCHECK_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <SOURCE_DIR>/shellcheck ${TEST_INSTALL_PREFIX}/bin/shellcheck
)
