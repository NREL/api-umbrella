# libcidr: CIDR IP calculations for libcidr-ffi LuaRock
ExternalProject_Add(
  libcidr
  URL https://www.over-yonder.net/~fullermd/projects/libcidr/libcidr-${LIBCIDR_VERSION}.tar.xz
  URL_HASH MD5=${LIBCIDR_HASH}
  # Rename file to tar.gz as a weird hack for CMake 2.8 not supporting tar.xz
  # files (but this still manages to work, at least if xz is installed).
  DOWNLOAD_NAME libcidr-${LIBCIDR_VERSION}.tar.gz
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND make PREFIX=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install NO_DOCS=1 NO_EXAMPLES=1 PREFIX=${INSTALL_PREFIX_EMBEDDED} DESTDIR=${STAGE_DIR}
)
