# Unbound: Local DNS server for testing DNS changes

set(UNBOUND_VERSION 1.7.0)
set(UNBOUND_HASH 94dd9071fb13d8ccd122a3ac67c4524a3324d0e771fc7a8a7c49af8abfb926a2)

ExternalProject_Add(
  unbound
  EXCLUDE_FROM_ALL 1
  URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz
  URL_HASH SHA256=${UNBOUND_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX}
)
