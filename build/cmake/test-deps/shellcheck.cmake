set(SHELLCHECK_VERSION 0.5.0)
set(SHELLCHECK_HASH 475e14bf2705ad4a16d405fa64b94c2eb151a914d5a165ce13e8f9344e6145893f685a650cd32d45a7ab236dedf55f76b31db82e2ef76ad6175a87dd89109790)

ExternalProject_Add(
  shellcheck
  EXCLUDE_FROM_ALL 1
  URL https://storage.googleapis.com/shellcheck/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz
  URL_HASH SHA512=${SHELLCHECK_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <SOURCE_DIR>/shellcheck ${TEST_INSTALL_PREFIX}/bin/shellcheck
)
