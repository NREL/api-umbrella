set(SHELLCHECK_VERSION 0.4.7)
set(SHELLCHECK_HASH 64bf19a1292f0357c007b615150b6e58dba138bc7bf168c5a5e27016f8b4f802afd9950be8be46bf9e4833f98ae81c6e7b1761a3a76ddbba2a04929265433134)

ExternalProject_Add(
  shellcheck
  EXCLUDE_FROM_ALL 1
  URL https://storage.googleapis.com/shellcheck/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz
  URL_HASH SHA512=${SHELLCHECK_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <SOURCE_DIR>/shellcheck ${TEST_INSTALL_PREFIX}/bin/shellcheck
)
