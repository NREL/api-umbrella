# runit's svlogd as alternative to perp's tinylog with more features.
ExternalProject_Add(
  runit
  URL http://smarden.org/runit/runit-${RUNIT_VERSION}.tar.gz
  URL_HASH MD5=${RUNIT_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cd runit-${RUNIT_VERSION}/src && make svlogd
  INSTALL_COMMAND install -D -m 755 runit-${RUNIT_VERSION}/src/svlogd ${STAGE_EMBEDDED_DIR}/bin/svlogd
)
