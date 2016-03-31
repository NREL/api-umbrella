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

ExternalProject_Add(
  openresty
  DEPENDS libgeoip ngx_dyups ngx_txid pcre
  URL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
  URL_HASH MD5=${OPENRESTY_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}/openresty --with-cc-opt=-I${STAGE_EMBEDDED_DIR}/include "--with-ld-opt=-L${STAGE_EMBEDDED_DIR}/lib -Wl,-rpath,${INSTALL_PREFIX_EMBEDDED}/lib,-rpath,${STAGE_EMBEDDED_DIR}/openresty/luajit/lib,-rpath,${STAGE_EMBEDDED_DIR}/lib" --error-log-path=stderr --with-ipv6 --with-pcre=${PCRE_SOURCE_DIR} --with-pcre-opt=-g --with-pcre-conf-opt=--enable-unicode-properties --with-pcre-jit --with-http_geoip_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_realip_module --with-http_ssl_module --with-http_stub_status_module --add-module=${NGX_DYUPS_SOURCE_DIR} --add-module=${NGX_TXID_SOURCE_DIR}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/bin/resty ./resty
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/luajit/bin/luajit-2.1.0-beta1 ./luajit
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/sbin && cd ${STAGE_EMBEDDED_DIR}/sbin && ln -snf ../openresty/nginx/sbin/nginx ./nginx
)
