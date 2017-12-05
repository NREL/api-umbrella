# Unbound: Local DNS server for testing DNS changes

set(UNBOUND_VERSION 1.6.7)
set(UNBOUND_HASH 4e7bd43d827004c6d51bef73adf941798e4588bdb40de5e79d89034d69751c9f)

ExternalProject_Add(
  unbound
  EXCLUDE_FROM_ALL 1
  URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz
  URL_HASH SHA256=${UNBOUND_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX}
)
