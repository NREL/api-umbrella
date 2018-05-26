# OpenResty and nginx plugins

include(${CMAKE_SOURCE_DIR}/build/cmake/deps/libgeoip.cmake)

set(LUAROCKS_VERSION 2.4.4)
set(LUAROCKS_HASH 04e8b19d565e86b1d08f745adc4b1a56)
set(OPENRESTY_VERSION 1.13.6.2)
set(OPENRESTY_HASH d95bc4bbe15e4b045a0593b4ecc0db38)
set(OPENSSL_VERSION 1.0.2o)
set(OPENSSL_HASH ec3f5c9714ba0fd45cb4e087301eb1336c317e0d20b575a125050470e8089e4d)
set(PCRE_VERSION 8.42)
set(PCRE_HASH 085b6aa253e0f91cae70b3cdbe8c1ac2)

# Pull in newer version of PCRE (8.20+) for OpenResty to enable PCRE JIT.
ExternalProject_Add(
  pcre
  EXCLUDE_FROM_ALL 1
  URL https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.bz2
  URL_HASH MD5=${PCRE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(pcre SOURCE_DIR)
set(PCRE_SOURCE_DIR ${SOURCE_DIR})

# OpenResty's ssl_certificate_by_lua functionality requires OpenSSL 1.0.2e+
ExternalProject_Add(
  openssl
  EXCLUDE_FROM_ALL 1
  URL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
  URL_HASH SHA256=${OPENSSL_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(openssl SOURCE_DIR)
set(OPENSSL_SOURCE_DIR ${SOURCE_DIR})

list(APPEND OPENRESTY_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND OPENRESTY_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED}/openresty)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-cc-opt=-I${STAGE_EMBEDDED_DIR}/include)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-ld-opt=-L${STAGE_EMBEDDED_DIR}/lib)
list(APPEND OPENRESTY_CONFIGURE_CMD --error-log-path=stderr)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-ipv6)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-openssl=${OPENSSL_SOURCE_DIR})
list(APPEND OPENRESTY_CONFIGURE_CMD --with-pcre=${PCRE_SOURCE_DIR})
list(APPEND OPENRESTY_CONFIGURE_CMD --with-pcre-opt=-g)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-pcre-conf-opt=--enable-unicode-properties)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-pcre-jit)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-http_geoip_module)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-http_gunzip_module)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-http_gzip_static_module)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-http_realip_module)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-http_ssl_module)
list(APPEND OPENRESTY_CONFIGURE_CMD --with-http_stub_status_module)

ExternalProject_Add(
  openresty
  EXCLUDE_FROM_ALL 1
  DEPENDS libgeoip openssl pcre
  URL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
  URL_HASH MD5=${OPENRESTY_HASH}
  BUILD_IN_SOURCE 1
  # Patch opm to allow it to pick up dynamic LUA_PATH and LUA_CPATH, since we
  # need different paths while performing staged installations.
  PATCH_COMMAND patch -p1 < ${CMAKE_SOURCE_DIR}/build/patches/openresty-opm.patch
    # Similarly, patch openresty's configure process so it doesn't introduce a
    # hard-coded path to nginx. This allows nginx to be picked up on the normal
    # PATH semantics, so it can worked in staged environments at different
    # locations.
    COMMAND patch -p1 < ${CMAKE_SOURCE_DIR}/build/patches/openresty-cli.patch
  CONFIGURE_COMMAND ${OPENRESTY_CONFIGURE_CMD}
  # Wipe the .openssl directory inside the openssl dir, or else openresty
  # will fail to build on rebuilds: https://trac.nginx.org/nginx/ticket/583
  BUILD_COMMAND COMMAND cd ${OPENSSL_SOURCE_DIR} && rm -rf .openssl
    COMMAND make
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND chrpath -d ${STAGE_EMBEDDED_DIR}/openresty/nginx/sbin/nginx
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/bin/opm ./opm
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/bin/resty ./resty
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/luajit/bin/luajit ./luajit
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/sbin && cd ${STAGE_EMBEDDED_DIR}/sbin && ln -snf ../openresty/nginx/sbin/nginx ./nginx
)

# LuaRocks: Lua dependency management
ExternalProject_Add(
  luarocks
  EXCLUDE_FROM_ALL 1
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
