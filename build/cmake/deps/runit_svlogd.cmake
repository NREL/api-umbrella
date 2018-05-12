# runit's svlogd as alternative to perp's tinylog with more features.

set(RUNIT_VERSION 2.1.2)
set(RUNIT_HASH 6c985fbfe3a34608eb3c53dc719172c4)

ExternalProject_Add(
  runit_svlogd
  EXCLUDE_FROM_ALL 1
  URL http://smarden.org/runit/runit-${RUNIT_VERSION}.tar.gz
  URL_HASH MD5=${RUNIT_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cd runit-${RUNIT_VERSION}/src && make svlogd
  INSTALL_COMMAND install -D -m 755 runit-${RUNIT_VERSION}/src/svlogd ${STAGE_EMBEDDED_DIR}/bin/svlogd
)
