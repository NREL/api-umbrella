# Unbound: Local DNS server for testing DNS changes

set(UNBOUND_VERSION 1.6.8)
set(UNBOUND_HASH e3b428e33f56a45417107448418865fe08d58e0e7fea199b855515f60884dd49)

ExternalProject_Add(
  unbound
  EXCLUDE_FROM_ALL 1
  URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz
  URL_HASH SHA256=${UNBOUND_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX}
)
