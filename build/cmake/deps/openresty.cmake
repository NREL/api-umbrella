# OpenResty and nginx plugins

include(${CMAKE_SOURCE_DIR}/build/cmake/deps/libgeoip.cmake)

set(LUAROCKS_VERSION 2.4.3)
set(LUAROCKS_HASH 37bb60fe084ca4f6c871d31bd248d5cc)
set(NGX_DYUPS_VERSION a5e75737e04ff3e5040a80f5f739171e96c3359c)
set(NGX_DYUPS_HASH e16860efcd0629f38f514469052d998a)
set(NGX_TXID_VERSION f1c197cb9c42e364a87fbb28d5508e486592ca42)
set(NGX_TXID_HASH 408ee86eb6e42e27a51514f711c41d6b)
set(OPENRESTY_VERSION 1.13.6.1)
set(OPENRESTY_HASH 637f82d0b36c74aec1c01bd3b8e0289c)
set(OPENSSL_VERSION 1.0.2n)
set(OPENSSL_HASH 370babb75f278c39e0c50e8c4e7493bc0f18db6867478341a832a982fd15a8fe)
set(PCRE_VERSION 8.41)
set(PCRE_HASH c160d22723b1670447341b08c58981c1)

# ngx_dyups: Dynamic upstream handling for handling DNS changes
ExternalProject_Add(
  ngx_dyups
  EXCLUDE_FROM_ALL 1
  URL https://github.com/yzprofile/ngx_http_dyups_module/archive/${NGX_DYUPS_VERSION}.tar.gz
  URL_HASH MD5=${NGX_DYUPS_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(ngx_dyups SOURCE_DIR)
set(NGX_DYUPS_SOURCE_DIR ${SOURCE_DIR})

# ngx_txid: Generate unique request IDs
ExternalProject_Add(
  ngx_txid
  EXCLUDE_FROM_ALL 1
  URL https://github.com/streadway/ngx_txid/archive/${NGX_TXID_VERSION}.tar.gz
  URL_HASH MD5=${NGX_TXID_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(ngx_txid SOURCE_DIR)
set(NGX_TXID_SOURCE_DIR ${SOURCE_DIR})

# Pull in newer version of PCRE (8.20+) for OpenResty to enable PCRE JIT.
ExternalProject_Add(
  pcre
  EXCLUDE_FROM_ALL 1
  URL http://ftp.cs.stanford.edu/pub/exim/pcre/pcre-${PCRE_VERSION}.tar.bz2
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
if(ENABLE_TEST_DEPENDENCIES)
  list(APPEND OPENRESTY_CONFIGURE_CMD "--with-ld-opt=-L${STAGE_EMBEDDED_DIR}/lib")
else()
  list(APPEND OPENRESTY_CONFIGURE_CMD "--with-ld-opt=-L${STAGE_EMBEDDED_DIR}/lib")
endif()
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
list(APPEND OPENRESTY_CONFIGURE_CMD --add-module=${NGX_DYUPS_SOURCE_DIR})
list(APPEND OPENRESTY_CONFIGURE_CMD --add-module=${NGX_TXID_SOURCE_DIR})

ExternalProject_Add(
  openresty
  EXCLUDE_FROM_ALL 1
  DEPENDS libgeoip ngx_dyups ngx_txid openssl pcre
  URL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
  URL_HASH MD5=${OPENRESTY_HASH}
  BUILD_IN_SOURCE 1
  # Patch opm to allow it to pick up dynamic LUA_PATH and LUA_CPATH, since we
  # need different paths while performing staged installations.
  PATCH_COMMAND patch -p1 < ${CMAKE_SOURCE_DIR}/build/patches/opm.patch
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
