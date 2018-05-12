# libcidr: CIDR IP calculations for libcidr-ffi LuaRock

set(LIBCIDR_VERSION 1.2.3)
set(LIBCIDR_HASH c5efcc7ae114fdaa5583f58dacecd9de)

ExternalProject_Add(
  libcidr
  EXCLUDE_FROM_ALL 1
  URL https://www.over-yonder.net/~fullermd/projects/libcidr/libcidr-${LIBCIDR_VERSION}.tar.xz
  URL_HASH MD5=${LIBCIDR_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND make PREFIX=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install NO_DOCS=1 NO_EXAMPLES=1 PREFIX=${INSTALL_PREFIX_EMBEDDED} DESTDIR=${STAGE_DIR}
)
