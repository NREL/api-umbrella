# PhantomJS: Headless WebKit for testing.
ExternalProject_Add(
  phantomjs
  URL https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-x86_64.tar.bz2
  URL_HASH MD5=${PHANTOMJS_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <SOURCE_DIR>/bin/phantomjs ${TEST_INSTALL_PREFIX}/bin/phantomjs
)
