# Perp: Process supervision and control

set(PERP_VERSION 2.07)
set(PERP_HASH a2acc7425d556d9635a25addcee9edb5)

ExternalProject_Add(
  perp
  EXCLUDE_FROM_ALL 1
  URL http://b0llix.net/perp/distfiles/perp-${PERP_VERSION}.tar.gz
  URL_HASH MD5=${PERP_HASH}
  PATCH_COMMAND sed -i -e "s%BINDIR.*%BINDIR = ${INSTALL_PREFIX_EMBEDDED}/bin%" conf.mk
    COMMAND sed -i -e "s%SBINDIR.*%SBINDIR = ${INSTALL_PREFIX_EMBEDDED}/sbin%" conf.mk
    COMMAND sed -i -e "s%MANDIR.*%MANDIR = ${INSTALL_PREFIX_EMBEDDED}/share/man%" conf.mk
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND make
    COMMAND make strip
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)
