set(SHELLCHECK_VERSION 0.4.6)
set(SHELLCHECK_HASH d9ac3e4fb2383b2d6862415e8052459ce24fd5402806b9ce739990d5c1cccebe4121288df29de32dcef5daa115874ddf7f9730de256bf134ee11cd9704aaa64c)

ExternalProject_Add(
  shellcheck
  EXCLUDE_FROM_ALL 1
  URL https://storage.googleapis.com/shellcheck/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz
  URL_HASH SHA512=${SHELLCHECK_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <SOURCE_DIR>/shellcheck ${TEST_INSTALL_PREFIX}/bin/shellcheck
)
