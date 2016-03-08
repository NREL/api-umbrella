cmake_minimum_required(VERSION 2.8.7 FATAL_ERROR)
project(api-umbrella)

set(CMAKE_INSTALL_PREFIX /opt/api-umbrella)
set_directory_properties(PROPERTIES EP_PREFIX build/cmake)

set(EXTERNAL_PREFIX_EMBEDDED ${CMAKE_INSTALL_PREFIX}/embedded)
set(EXTERNAL_DESTDIR <INSTALL_DIR>/dest)
set(EXTERNAL_DESTDIR_EMBEDDED <INSTALL_DIR>/dest${EXTERNAL_PREFIX_EMBEDDED})
set(VENDOR_DIR ${EXTERNAL_DESTDIR_EMBEDDED}/apps/core/shared/vendor)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
MESSAGE( STATUS "CMAKE_BINARY_DIR:         " ${CMAKE_BINARY_DIR} )
MESSAGE( STATUS "EP_PREFIX:         " ${EP_PREFIX} )
set(LUAROCKS_CMD env LUA_PATH='${EXTERNAL_DESTDIR_EMBEDDED}/openresty/luajit/share/lua/5.1/?.lua;${EXTERNAL_DESTDIR_EMBEDDED}/openresty/luajit/share/lua/5.1/?/init.lua;;' ${EXTERNAL_DESTDIR_EMBEDDED}/bin/luarocks)

include(ExternalProject)

set(BUNDLER_VERSION 1.11.2)
set(ELASTICSEARCH_VERSION 1.7.5)
set(GOLANG_VERSION 1.5.3)
set(LIBCIDR_VERSION 1.2.3)
set(LIBGEOIP_VERSION 1.6.9)
set(LUAROCKS_VERSION 2.3.0)
set(LUAROCK_ARGPARSE_VERSION 0.4.1-1)
set(LUAROCK_CMSGPACK_VERSION 0.4.0-0)
set(LUAROCK_ICONV_VERSION 7-1)
set(LUAROCK_INSPECT_VERSION 3.0-4)
set(LUAROCK_LIBCIDR_VERSION 0.1.0-1)
set(LUAROCK_LUACHECK_VERSION 0.14.0-1)
set(LUAROCK_LUAPOSIX_VERSION 33.4.0-1)
set(LUAROCK_LUASOCKET_VERSION 2.0.2-6)
set(LUAROCK_LYAML_VERSION 6.0-1)
set(LUAROCK_PENLIGHT_VERSION 1.3.2-2)
set(LUAROCK_RESTY_HTTP_VERSION 0.07-0)
set(LUA_RESTY_DNS_CACHE_VERSION 691613739a32f8405e56e56547270b9f72e77c34)
set(LUA_RESTY_LOGGER_SOCKET_VERSION d435ea6052c0d252cf7f89fe4b7cb9c69306de93)
set(LUA_RESTY_SHCACHE_VERSION fb2e275c2cdca08eaa34a7b73375e41ac3eff200)
set(LUA_RESTY_UUID_VERSION 70a01d8a6c2cd7ef8bbe622658b58ec30b6b90d4)
set(MORA_VERSION fea22d544a961ef5cd66dde405cf452b1ae33d2c)
set(NGX_DYUPS_VERSION 3683b0031c86d5d240bc0b7caf215dff29597fb2)
set(NGX_TXID_VERSION f1c197cb9c42e364a87fbb28d5508e486592ca42)
set(OPENRESTY_VERSION 1.9.7.3)
set(PCRE_VERSION 8.38)
set(PERP_VERSION 2.07)
set(RUBY_VERSION 2.2.4)
set(RUNIT_VERSION 2.1.2)
set(TRAFFICSERVER_VERSION 5.3.2)
set(UNBOUND_VERSION 1.5.8)

find_package(LibXml2 REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_search_module(LIBUUID REQUIRED uuid)
pkg_search_module(LIBFFI REQUIRED libffi)

function(luarocks_install package version)
  ExternalProject_Add(
    luarock_${package}
    DEPENDS luarocks
    DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://luarocks.org/${package}-${version}.rockspec
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${EXTERNAL_DESTDIR_EMBEDDED}/bin/luarocks --tree=${VENDOR_DIR} install ${package} ${version} ${ARGV2}
  )
endfunction(luarocks_install)

ExternalProject_Add(
  elasticsearch
  URL https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz
  URL_HASH SHA1=23353fcfdf4897997eb36624afa0af62562f9b3c
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a <SOURCE_DIR>/ ${EXTERNAL_DESTDIR_EMBEDDED}/elasticsearch/
    COMMAND cd ${EXTERNAL_DESTDIR_EMBEDDED}/bin && ln -snf ../elasticsearch/bin/plugin ./plugin
    COMMAND cd ${EXTERNAL_DESTDIR_EMBEDDED}/bin && ln -snf ../elasticsearch/bin/elasticsearch ./elasticsearch
)

ExternalProject_Add(
  libcidr
  URL https://www.over-yonder.net/~fullermd/projects/libcidr/libcidr-${LIBCIDR_VERSION}.tar.xz
  URL_HASH MD5=c5efcc7ae114fdaa5583f58dacecd9de
  # Rename file to tar.gz as a weird hack for CMake 2.8 not supporting tar.xz
  # files (but this still manages to work, at least if xz is installed).
  DOWNLOAD_NAME libcidr-${LIBCIDR_VERSION}.tar.gz
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND make PREFIX=${EXTERNAL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install NO_DOCS=1 NO_EXAMPLES=1 PREFIX=${EXTERNAL_PREFIX_EMBEDDED} DESTDIR=${EXTERNAL_DESTDIR}
)

ExternalProject_Add(
  geolitecity
  DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz
    COMMAND cd <SOURCE_DIR> && gunzip -c GeoLiteCityv6.dat.gz > GeoLiteCityv6.dat
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/GeoLiteCityv6.dat ${EXTERNAL_DESTDIR_EMBEDDED}/var/db/geoip/city-v6.dat
)

ExternalProject_Add(
  golang
  URL https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz
  URL_HASH SHA256=43afe0c5017e502630b1aea4d44b8a7f059bf60d7f29dfd58db454d4e4e0ae53
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(golang SOURCE_DIR)
set(GOLANG_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  glide
  DEPENDS golang
  URL https://github.com/Masterminds/glide/releases/download/0.9.1/glide-0.9.1-linux-amd64.tar.gz
  URL_HASH MD5=6120ed13c8f048801b255e1f8a4819c3
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(glide SOURCE_DIR)
set(GLIDE_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  mora
  DEPENDS glide
  GIT_REPOSITORY https://github.com/emicklei/mora.git
  GIT_TAG ${MORA_VERSION}
  UPDATE_COMMAND ""
  SOURCE_DIR ${CMAKE_SOURCE_DIR}/gocode/src/github.com/emicklei/mora
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cp ${CMAKE_SOURCE_DIR}/build/mora/glide.yaml <SOURCE_DIR>/glide.yaml
    COMMAND cp ${CMAKE_SOURCE_DIR}/build/mora/glide.lock <SOURCE_DIR>/glide.lock
    COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${GLIDE_SOURCE_DIR}:${CMAKE_SOURCE_DIR}/gocode/bin:$ENV{PATH} GOPATH=${CMAKE_SOURCE_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} GO15VENDOREXPERIMENT=1 glide install
    COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${GLIDE_SOURCE_DIR}:${CMAKE_SOURCE_DIR}/gocode/bin:$ENV{PATH} GOPATH=${CMAKE_SOURCE_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} GO15VENDOREXPERIMENT=1 go install
  INSTALL_COMMAND install -D -m 755 ${CMAKE_SOURCE_DIR}/gocode/bin/mora ${EXTERNAL_DESTDIR_EMBEDDED}/bin/mora
)

ExternalProject_Add(
  libgeoip
  URL https://github.com/maxmind/geoip-api-c/releases/download/v${LIBGEOIP_VERSION}/GeoIP-${LIBGEOIP_VERSION}.tar.gz
  URL_HASH MD5=7475942dc8155046dddb4846f587a7e6
  CONFIGURE_COMMAND env LDFLAGS=-Wl,-rpath,${CMAKE_INSTALL_PREFIX}/lib <SOURCE_DIR>/configure --prefix=${EXTERNAL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${EXTERNAL_DESTDIR}
)

ExternalProject_Add(
  ngx_dyups
  GIT_REPOSITORY https://github.com/yzprofile/ngx_http_dyups_module.git
  GIT_TAG ${NGX_DYUPS_VERSION}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(ngx_dyups SOURCE_DIR)
set(NGX_DYUPS_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  ngx_txid
  GIT_REPOSITORY https://github.com/streadway/ngx_txid.git
  GIT_TAG ${NGX_TXID_VERSION}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(ngx_txid SOURCE_DIR)
set(NGX_TXID_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  pcre
  URL http://ftp.cs.stanford.edu/pub/exim/pcre/pcre-${PCRE_VERSION}.tar.bz2
  URL_HASH MD5=00aabbfe56d5a48b270f999b508c5ad2
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
  URL_HASH MD5=33579b96a8c22bedee97eadfc99d9564
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${EXTERNAL_PREFIX_EMBEDDED}/openresty --with-cc-opt=-I${EXTERNAL_DESTDIR_EMBEDDED}/include "--with-ld-opt=-L${EXTERNAL_DESTDIR_EMBEDDED}/lib -Wl,-rpath,${EXTERNAL_PREFIX_EMBEDDED}/lib,-rpath,${EXTERNAL_DESTDIR_EMBEDDED}/openresty/luajit/lib,-rpath,${EXTERNAL_DESTDIR_EMBEDDED}/lib" --error-log-path=stderr --with-ipv6 --with-pcre=${PCRE_SOURCE_DIR} --with-pcre-opt=-g --with-pcre-conf-opt=--enable-unicode-properties --with-pcre-jit --with-http_geoip_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_realip_module --with-http_ssl_module --with-http_stub_status_module --add-module=${NGX_DYUPS_SOURCE_DIR} --add-module=${NGX_TXID_SOURCE_DIR}
  INSTALL_COMMAND make install DESTDIR=${EXTERNAL_DESTDIR}
    COMMAND cd ${EXTERNAL_DESTDIR_EMBEDDED}/bin && ln -snf ../openresty/bin/resty ./resty
    COMMAND cd ${EXTERNAL_DESTDIR_EMBEDDED}/bin && ln -snf ../openresty/luajit/bin/luajit-2.1.0-beta1 ./luajit
    COMMAND mkdir -p ${EXTERNAL_DESTDIR_EMBEDDED}/sbin && cd ${EXTERNAL_DESTDIR_EMBEDDED}/sbin && ln -snf ../openresty/nginx/sbin/nginx ./nginx
)

ExternalProject_Add(
  luarocks
  DEPENDS openresty
  URL http://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz
  URL_HASH MD5=a38126684cf42b7d0e7a3c7cf485defb
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${EXTERNAL_PREFIX_EMBEDDED}/openresty/luajit --with-lua=${EXTERNAL_DESTDIR_EMBEDDED}/openresty/luajit --with-lua-include=${EXTERNAL_DESTDIR_EMBEDDED}/openresty/luajit/include/luajit-2.1 --lua-suffix=jit-2.1.0-beta1
  BUILD_COMMAND make build
  INSTALL_COMMAND make install DESTDIR=${EXTERNAL_DESTDIR}
    COMMAND cd ${EXTERNAL_DESTDIR_EMBEDDED}/bin && ln -snf ../openresty/luajit/bin/luarocks ./luarocks
)

luarocks_install(lua-resty-http ${LUAROCK_RESTY_HTTP_VERSION})
luarocks_install(argparse ${LUAROCK_ARGPARSE_VERSION})
luarocks_install(inspect ${LUAROCK_INSPECT_VERSION})
luarocks_install(libcidr-ffi ${LUAROCK_LIBCIDR_VERSION} CIDR_DIR=${EXTERNAL_DESTDIR_EMBEDDED})
luarocks_install(lua-cmsgpack ${LUAROCK_CMSGPACK_VERSION})
luarocks_install(lua-iconv ${LUAROCK_ICONV_VERSION})
luarocks_install(luaposix ${LUAROCK_LUAPOSIX_VERSION})
luarocks_install(luasocket ${LUAROCK_LUASOCKET_VERSION})
luarocks_install(lyaml ${LUAROCK_LYAML_VERSION})
luarocks_install(penlight ${LUAROCK_PENLIGHT_VERSION})
luarocks_install(luacheck ${LUAROCK_LUACHECK_VERSION})

ExternalProject_Add(
  lua_resty_dns_cache
  GIT_REPOSITORY https://github.com/hamishforbes/lua-resty-dns-cache.git
  GIT_TAG ${LUA_RESTY_DNS_CACHE_VERSION}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/dns/cache.lua   ${VENDOR_LUA_DIR}/resty/dns/cache.lua
)

ExternalProject_Add(
  lua_resty_logger_socket
  GIT_REPOSITORY https://github.com/cloudflare/lua-resty-logger-socket.git
  GIT_TAG ${LUA_RESTY_LOGGER_SOCKET_VERSION}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/logger/socket.lua  ${VENDOR_LUA_DIR}/resty/logger/socket.lua
)

ExternalProject_Add(
  lua_resty_shcache
  GIT_REPOSITORY https://github.com/cloudflare/lua-resty-shcache.git
  GIT_TAG ${LUA_RESTY_SHCACHE_VERSION}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/shcache.lua  ${VENDOR_LUA_DIR}/shcache.lua
)

ExternalProject_Add(
  perp
  URL http://b0llix.net/perp/distfiles/perp-${PERP_VERSION}.tar.gz
  URL_HASH MD5=a2acc7425d556d9635a25addcee9edb5
  PATCH_COMMAND sed -i -e "s%BINDIR.*%BINDIR = ${EXTERNAL_PREFIX_EMBEDDED}/bin%" conf.mk
    COMMAND sed -i -e "s%SBINDIR.*%SBINDIR = ${EXTERNAL_PREFIX_EMBEDDED}/sbin%" conf.mk
    COMMAND sed -i -e "s%MANDIR.*%MANDIR = ${EXTERNAL_PREFIX_EMBEDDED}/share/man%" conf.mk
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND make
    COMMAND make strip
  INSTALL_COMMAND make install DESTDIR=${EXTERNAL_DESTDIR}
)

ExternalProject_Add(
  ruby
  URL https://cache.ruby-lang.org/pub/ruby/2.2/ruby-${RUBY_VERSION}.tar.bz2
  URL_HASH SHA256=31203696adbfdda6f2874a2de31f7c5a1f3bcb6628f4d1a241de21b158cd5c76
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${EXTERNAL_PREFIX_EMBEDDED} --enable-load-relative --disable-install-doc
  INSTALL_COMMAND make install DESTDIR=${EXTERNAL_DESTDIR}
)

ExternalProject_Add(
  bundler
  DEPENDS ruby
  DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://rubygems.org/downloads/bundler-${BUNDLER_VERSION}.gem
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND env PATH=${EXTERNAL_DESTDIR_EMBEDDED}/bin:$ENV{PATH} gem install <SOURCE_DIR>/bundler-${BUNDLER_VERSION}.gem --no-rdoc --no-ri --env-shebang --local
)

ExternalProject_Add(
  runit
  URL http://smarden.org/runit/runit-${RUNIT_VERSION}.tar.gz
  URL_HASH MD5=6c985fbfe3a34608eb3c53dc719172c4
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cd runit-${RUNIT_VERSION}/src && make svlogd
  INSTALL_COMMAND install -D -m 755 runit-${RUNIT_VERSION}/src/svlogd ${EXTERNAL_DESTDIR_EMBEDDED}/bin/svlogd
)

ExternalProject_Add(
  trafficserver
  URL http://mirror.olnevhost.net/pub/apache/trafficserver/trafficserver-${TRAFFICSERVER_VERSION}.tar.bz2
  URL_HASH MD5=c8e5f3e81da643ea79cba0494ed37d45
  CONFIGURE_COMMAND env SPHINXBUILD=false LDFLAGS=-Wl,-rpath,${EXTERNAL_DESTDIR_EMBEDDED}/lib <SOURCE_DIR>/configure --prefix=${EXTERNAL_PREFIX_EMBEDDED} --enable-experimental-plugins
  INSTALL_COMMAND make install DESTDIR=${EXTERNAL_DESTDIR}
    COMMAND rm -f ${EXTERNAL_DESTDIR_EMBEDDED}/bin/traffic_sac
)

ExternalProject_Add(
  unbound
  URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz
  URL_HASH SHA256=33567a20f73e288f8daa4ec021fbb30fe1824b346b34f12677ad77899ecd09be
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>/test
  INSTALL_COMMAND make install
)
