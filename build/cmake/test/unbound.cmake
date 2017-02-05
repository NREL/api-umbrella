# Unbound: Local DNS server for testing DNS changes
ExternalProject_Add(
  unbound
  URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz
  URL_HASH SHA256=${UNBOUND_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX}
)
