# OpenResty and nginx plugins

# ngx_dyups: Dynamic upstream handling for handling DNS changes
ExternalProject_Add(
  ngx_dyups
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
  URL ftp://ftp.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
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
list(APPEND OPENRESTY_CONFIGURE_CMD "--with-ld-opt=-L${STAGE_EMBEDDED_DIR}/lib -Wl,-rpath,${INSTALL_PREFIX_EMBEDDED}/lib,-rpath,${STAGE_EMBEDDED_DIR}/openresty/luajit/lib,-rpath,${STAGE_EMBEDDED_DIR}/lib")
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
  DEPENDS libgeoip ngx_dyups ngx_txid openssl pcre
  URL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
  URL_HASH MD5=${OPENRESTY_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${OPENRESTY_CONFIGURE_CMD}
  # Wipe the .openssl directory inside the openssl dir, or else openresty
  # will fail to build on rebuilds: https://trac.nginx.org/nginx/ticket/583
  BUILD_COMMAND COMMAND cd ${OPENSSL_SOURCE_DIR} && rm -rf .openssl
    COMMAND make
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/bin/resty ./resty
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/luajit/bin/luajit-2.1.0-beta2 ./luajit
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/sbin && cd ${STAGE_EMBEDDED_DIR}/sbin && ln -snf ../openresty/nginx/sbin/nginx ./nginx
)
