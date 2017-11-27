ExternalProject_Add(
  cjose
  URL https://github.com/cisco/cjose/archive/${CJOSE_VERSION}.tar.gz
  URL_HASH MD5=${CJOSE_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)
