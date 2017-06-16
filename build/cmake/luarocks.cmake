# LuaRocks: Lua dependency management
ExternalProject_Add(
  luarocks
  DEPENDS openresty
  URL http://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz
  URL_HASH MD5=${LUAROCKS_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}/openresty/luajit --with-lua=${STAGE_EMBEDDED_DIR}/openresty/luajit --with-lua-include=${STAGE_EMBEDDED_DIR}/openresty/luajit/include/luajit-2.1 --lua-suffix=jit
  BUILD_COMMAND make build
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/luajit/bin/luarocks ./luarocks
    COMMAND rm -rf ${VENDOR_DIR}/share/lua ${VENDOR_DIR}/lib/luarocks
    COMMAND rm -rf ${TEST_VENDOR_DIR}/share/lua ${TEST_VENDOR_DIR}/lib/luarocks
)
