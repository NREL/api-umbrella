# PhantomJS: Headless WebKit for testing.

set(PHANTOMJS_VERSION 2.1.1)
set(PHANTOMJS_HASH 1c947d57fce2f21ce0b43fe2ed7cd361)

ExternalProject_Add(
  phantomjs
  EXCLUDE_FROM_ALL 1
  URL https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-x86_64.tar.bz2
  URL_HASH MD5=${PHANTOMJS_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <SOURCE_DIR>/bin/phantomjs ${TEST_INSTALL_PREFIX}/bin/phantomjs
)
