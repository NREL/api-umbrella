# LuaRocks: Lua dependency management
ExternalProject_Add(
  luarocks
  DEPENDS openresty
  URL http://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz
  URL_HASH MD5=${LUAROCKS_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}/openresty/luajit --with-lua=${STAGE_EMBEDDED_DIR}/openresty/luajit --with-lua-include=${STAGE_EMBEDDED_DIR}/openresty/luajit/include/luajit-2.1 --lua-suffix=jit-2.1.0-beta2
  BUILD_COMMAND make build
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/luajit/bin/luarocks ./luarocks
)

function(luarocks_install package version)
  ExternalProject_Add(
    luarock_${package}
    DEPENDS luarocks ${ARGV3}
    DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://luarocks.org/${package}-${version}.rockspec
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${LUAROCKS_CMD} --tree=${VENDOR_DIR} install ${package} ${version} ${ARGV2}
  )
endfunction()

function(test_luarocks_install package version)
  ExternalProject_Add(
    luarock_${package}
    DEPENDS luarocks ${ARGV3}
    DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://luarocks.org/${package}-${version}.rockspec
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${LUAROCKS_CMD} --tree=${TEST_VENDOR_DIR} install ${package} ${version} ${ARGV2}
  )
endfunction()
