ExternalProject_Add(
  shellcheck
  URL https://github.com/koalaman/shellcheck/archive/v${SHELLCHECK_VERSION}.tar.gz
  URL_HASH MD5=${SHELLCHECK_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cabal sandbox init
    COMMAND cabal update
    COMMAND cabal install --reinstall --disable-library-profiling --disable-profiling --disable-optimization --disable-tests --disable-coverage --disable-benchmarks --disable-documentation
  INSTALL_COMMAND mkdir -p ${TEST_INSTALL_PREFIX}/bin
    COMMAND cp <SOURCE_DIR>/.cabal-sandbox/bin/shellcheck ${TEST_INSTALL_PREFIX}/bin/
)
