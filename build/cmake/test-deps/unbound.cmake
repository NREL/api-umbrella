# Unbound: Local DNS server for testing DNS changes

set(UNBOUND_VERSION 1.7.1)
set(UNBOUND_HASH 56e085ef582c5372a20207de179d0edb4e541e59f87be7d4ee1d00d12008628d)

ExternalProject_Add(
  unbound
  EXCLUDE_FROM_ALL 1
  URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz
  URL_HASH SHA256=${UNBOUND_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX}
)
