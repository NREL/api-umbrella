cmake_minimum_required(VERSION 2.8.7 FATAL_ERROR)
project(api-umbrella)

# Installation prefix
set(CMAKE_INSTALL_PREFIX /opt/api-umbrella)
set(INSTALL_PREFIX_EMBEDDED ${CMAKE_INSTALL_PREFIX}/embedded)

# Where to install cmake ExternalProjects.
set_directory_properties(PROPERTIES EP_PREFIX build/cmake)

# Where to stage installations during "make" phase.
set(STAGE_DIR ${CMAKE_SOURCE_DIR}/${EP_PREFIX}/stage)
set(STAGE_PREFIX_DIR ${STAGE_DIR}${CMAKE_INSTALL_PREFIX})
set(STAGE_EMBEDDED_DIR ${STAGE_DIR}${INSTALL_PREFIX_EMBEDDED})

# Where to install app-level vendor dependencies.
set(VENDOR_DIR ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
set(LUAROCKS_CMD env LUA_PATH='${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?.lua;${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?/init.lua;;' ${STAGE_EMBEDDED_DIR}/bin/luarocks)

# Define a timestamped release name for our app installations.
execute_process(COMMAND date -u +%Y%m%d%H%M%S OUTPUT_VARIABLE RELEASE_TIMESTAMP OUTPUT_STRIP_TRAILING_WHITESPACE)

include(ExternalProject)

# Define the versions of the various dependencies to build.
set(API_UMBRELLA_STATIC_SITE_VERSION 265714dbee04efa14f4d83e1f78f06ec492d9c6e)
set(API_UMBRELLA_STATIC_SITE_HASH 500d14f7417bee84169b2591f2d7722f)
set(BUNDLER_VERSION 1.11.2)
set(ELASTICSEARCH_VERSION 1.7.5)
set(ELASTICSEARCH_HASH 23353fcfdf4897997eb36624afa0af62562f9b3c)
set(GLIDE_VERSION 0.9.3)
set(GLIDE_HASH 220deb37963873d92dca4d21d450e8b0)
set(GOLANG_VERSION 1.5.3)
set(GOLANG_HASH 43afe0c5017e502630b1aea4d44b8a7f059bf60d7f29dfd58db454d4e4e0ae53)
set(LIBCIDR_VERSION 1.2.3)
set(LIBCIDR_HASH c5efcc7ae114fdaa5583f58dacecd9de)
set(LIBGEOIP_VERSION 1.6.9)
set(LIBGEOIP_HASH 7475942dc8155046dddb4846f587a7e6)
set(LIBRDKAFKA_VERSION 0.8.6)
set(LIBRDKAFKA_HASH 1b77543f9be82d3f700c0ef98f494990)
set(LUAROCKS_VERSION 2.3.0)
set(LUAROCKS_HASH a38126684cf42b7d0e7a3c7cf485defb)
set(LUAROCK_ARGPARSE_VERSION 0.4.1-1)
set(LUAROCK_CMSGPACK_VERSION 0.4.0-0)
set(LUAROCK_ICONV_VERSION 7-1)
set(LUAROCK_INSPECT_VERSION 3.0-4)
set(LUAROCK_LIBCIDR_VERSION 0.1.0-1)
set(LUAROCK_LUACHECK_VERSION 0.14.0-1)
set(LUAROCK_LUAPOSIX_VERSION 33.4.0-1)
set(LUAROCK_LUASOCKET_VERSION 2.0.2-6)
set(LUAROCK_LUATZ_VERSION 0.3-1)
set(LUAROCK_LUSTACHE_VERSION 1.3.1-0)
set(LUAROCK_LYAML_VERSION 6.0-1)
set(LUAROCK_PENLIGHT_VERSION 1.3.2-2)
set(LUAROCK_RESTY_HTTP_VERSION 0.07-0)
set(LUAROCK_RESTY_UUID_VERSION 1.0-1)
set(LUA_RESTY_DNS_CACHE_VERSION 691613739a32f8405e56e56547270b9f72e77c34)
set(LUA_RESTY_DNS_CACHE_HASH c7304c1f434ac251246904db51423d5e)
set(LUA_RESTY_LOGGER_SOCKET_VERSION d435ea6052c0d252cf7f89fe4b7cb9c69306de93)
set(LUA_RESTY_LOGGER_SOCKET_HASH 6d7273438100ddcdfa57bdbf1a8c3a01)
set(LUA_RESTY_SHCACHE_VERSION fb2e275c2cdca08eaa34a7b73375e41ac3eff200)
set(LUA_RESTY_SHCACHE_HASH 5d3cbcf8fbad1954cdcb3826afa41afe)
set(MONGODB_VERSION 3.0.10)
set(MONGODB_HASH 11bbde5690a4bf8ecab11983d0c65159)
set(MORA_VERSION fea22d544a961ef5cd66dde405cf452b1ae33d2c)
set(MORA_HASH 1e9c63acbbb0795ed00820a59c6cdcbc)
set(NGX_DYUPS_VERSION df1301c7458752fdbc21b9bfa913e13dc56cd855)
set(NGX_DYUPS_HASH 723ca4835a9557b92d50710b706e6caa)
set(NGX_TXID_VERSION f1c197cb9c42e364a87fbb28d5508e486592ca42)
set(NGX_TXID_HASH 408ee86eb6e42e27a51514f711c41d6b)
set(OPENRESTY_VERSION 1.9.7.4)
set(OPENRESTY_HASH 6e2d4a39c530524111ea50e3de67043a)
set(PCRE_VERSION 8.38)
set(PCRE_HASH 00aabbfe56d5a48b270f999b508c5ad2)
set(PERP_VERSION 2.07)
set(PERP_HASH a2acc7425d556d9635a25addcee9edb5)
set(RUBY_VERSION 2.2.4)
set(RUBY_HASH 31203696adbfdda6f2874a2de31f7c5a1f3bcb6628f4d1a241de21b158cd5c76)
set(RSYSLOG_VERSION 8.14.0)
set(RSYSLOG_HASH 443b5b1d2b84f5cd429d06d230af7fb2352336fa6449cb6484dbd4418a7ae7c2)
set(RUNIT_VERSION 2.1.2)
set(RUNIT_HASH 6c985fbfe3a34608eb3c53dc719172c4)
set(TRAFFICSERVER_VERSION 5.3.2)
set(TRAFFICSERVER_HASH c8e5f3e81da643ea79cba0494ed37d45)
set(UNBOUND_VERSION 1.5.8)
set(UNBOUND_HASH 33567a20f73e288f8daa4ec021fbb30fe1824b346b34f12677ad77899ecd09be)

function(require_program name)
  find_program(${name} ${name})
  if(NOT ${name})
    MESSAGE(FATAL_ERROR "Could not find ${name}")
  endif()
endfunction(require_program)

find_package(LibXml2 REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_search_module(LIBUUID REQUIRED uuid)
pkg_search_module(LIBFFI REQUIRED libffi)
require_program(rsync)

function(luarocks_install package version)
  ExternalProject_Add(
    luarock_${package}
    DEPENDS luarocks ${ARGV3}
    DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://luarocks.org/${package}-${version}.rockspec
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${STAGE_EMBEDDED_DIR}/bin/luarocks --tree=${VENDOR_DIR} install ${package} ${version} ${ARGV2}
  )
endfunction(luarocks_install)

#
# ElasticSearch: Analytics database
#
ExternalProject_Add(
  elasticsearch
  URL https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz
  URL_HASH SHA1=${ELASTICSEARCH_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a <SOURCE_DIR>/ ${STAGE_EMBEDDED_DIR}/elasticsearch/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../elasticsearch/bin/plugin ./plugin
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../elasticsearch/bin/elasticsearch ./elasticsearch
)

#
# libcidr: CIDR IP calculations for libcidr-ffi LuaRock
#
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

#
# libgeoip & GeoLiteCityv6.dat: GeoIP locations
#
ExternalProject_Add(
  libgeoip
  URL https://github.com/maxmind/geoip-api-c/releases/download/v${LIBGEOIP_VERSION}/GeoIP-${LIBGEOIP_VERSION}.tar.gz
  URL_HASH MD5=${LIBGEOIP_HASH}
  CONFIGURE_COMMAND env LDFLAGS=-Wl,-rpath,${CMAKE_INSTALL_PREFIX}/lib <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  geolitecity
  DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz
    COMMAND cd <SOURCE_DIR> && gunzip -c GeoLiteCityv6.dat.gz > GeoLiteCityv6.dat
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/GeoLiteCityv6.dat ${STAGE_EMBEDDED_DIR}/var/db/geoip/city-v6.dat
)

#
# MongoDB: General database
#
ExternalProject_Add(
  mongodb
  URL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${MONGODB_VERSION}.tgz
  URL_HASH MD5=${MONGODB_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a <SOURCE_DIR>/ ${STAGE_EMBEDDED_DIR}/
    # Trim our own distribution by removing some larger files we don't need for
    # API Umbrella.
    COMMAND rm -f ${STAGE_EMBEDDED_DIR}/bin/bsondump ${STAGE_EMBEDDED_DIR}/bin/mongoexport ${STAGE_EMBEDDED_DIR}/bin/mongofiles ${STAGE_EMBEDDED_DIR}/bin/mongoimport ${STAGE_EMBEDDED_DIR}/bin/mongooplog ${STAGE_EMBEDDED_DIR}/bin/mongoperf ${STAGE_EMBEDDED_DIR}/bin/mongos
)

#
# Mora: HTTP API for MongoDB (allowing OpenResty connectivity)
# Built with Go & Glide for dependencies
#
ExternalProject_Add(
  golang
  URL https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz
  URL_HASH SHA256=${GOLANG_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(golang SOURCE_DIR)
set(GOLANG_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  glide
  DEPENDS golang
  URL https://github.com/Masterminds/glide/releases/download/${GLIDE_VERSION}/glide-${GLIDE_VERSION}-linux-amd64.tar.gz
  URL_HASH MD5=${GLIDE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(glide SOURCE_DIR)
set(GLIDE_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  mora
  DEPENDS glide
  URL https://github.com/emicklei/mora/archive/${MORA_VERSION}.tar.gz
  URL_HASH MD5=${MORA_HASH}
  SOURCE_DIR ${CMAKE_SOURCE_DIR}/gocode/src/github.com/emicklei/mora
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cp ${CMAKE_SOURCE_DIR}/build/mora/glide.yaml <SOURCE_DIR>/glide.yaml
    COMMAND cp ${CMAKE_SOURCE_DIR}/build/mora/glide.lock <SOURCE_DIR>/glide.lock
    COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${GLIDE_SOURCE_DIR}:${CMAKE_SOURCE_DIR}/gocode/bin:$ENV{PATH} GOPATH=${CMAKE_SOURCE_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} GO15VENDOREXPERIMENT=1 glide install
    COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${GLIDE_SOURCE_DIR}:${CMAKE_SOURCE_DIR}/gocode/bin:$ENV{PATH} GOPATH=${CMAKE_SOURCE_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} GO15VENDOREXPERIMENT=1 go install
  INSTALL_COMMAND install -D -m 755 ${CMAKE_SOURCE_DIR}/gocode/bin/mora ${STAGE_EMBEDDED_DIR}/bin/mora
)

#
# OpenResty and nginx plugins
#

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
  UPDATE_COMMAND ""
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

#
# LuaRocks: Lua dependency management
#
ExternalProject_Add(
  luarocks
  DEPENDS openresty
  URL http://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz
  URL_HASH MD5=${LUAROCKS_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}/openresty/luajit --with-lua=${STAGE_EMBEDDED_DIR}/openresty/luajit --with-lua-include=${STAGE_EMBEDDED_DIR}/openresty/luajit/include/luajit-2.1 --lua-suffix=jit-2.1.0-beta1
  BUILD_COMMAND make build
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND cd ${STAGE_EMBEDDED_DIR}/bin && ln -snf ../openresty/luajit/bin/luarocks ./luarocks
)

#
# Perp: Process supervision and control
#
ExternalProject_Add(
  perp
  URL http://b0llix.net/perp/distfiles/perp-${PERP_VERSION}.tar.gz
  URL_HASH MD5=${PERP_HASH}
  PATCH_COMMAND sed -i -e "s%BINDIR.*%BINDIR = ${INSTALL_PREFIX_EMBEDDED}/bin%" conf.mk
    COMMAND sed -i -e "s%SBINDIR.*%SBINDIR = ${INSTALL_PREFIX_EMBEDDED}/sbin%" conf.mk
    COMMAND sed -i -e "s%MANDIR.*%MANDIR = ${INSTALL_PREFIX_EMBEDDED}/share/man%" conf.mk
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND make
    COMMAND make strip
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

# runit's svlogd as alternative to perp's tinylog with more features.
ExternalProject_Add(
  runit
  URL http://smarden.org/runit/runit-${RUNIT_VERSION}.tar.gz
  URL_HASH MD5=${RUNIT_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cd runit-${RUNIT_VERSION}/src && make svlogd
  INSTALL_COMMAND install -D -m 755 runit-${RUNIT_VERSION}/src/svlogd ${STAGE_EMBEDDED_DIR}/bin/svlogd
)

#
# Ruby & Bundler: For Rails web-app component
#
ExternalProject_Add(
  ruby
  URL https://cache.ruby-lang.org/pub/ruby/2.2/ruby-${RUBY_VERSION}.tar.bz2
  URL_HASH SHA256=${RUBY_HASH}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --enable-load-relative --disable-install-doc
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  bundler
  DEPENDS ruby
  DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://rubygems.org/downloads/bundler-${BUNDLER_VERSION}.gem
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} gem install <SOURCE_DIR>/bundler-${BUNDLER_VERSION}.gem --no-rdoc --no-ri --env-shebang --local
)

#
# RSYSLOG: Log buffering and processing
#
ExternalProject_Add(
  librdkafka
  URL https://github.com/edenhill/librdkafka/archive/${LIBRDKAFKA_VERSION}.tar.gz
  URL_HASH MD5=${LIBRDKAFKA_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  rsyslog
  DEPENDS librdkafka
  URL http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-${RSYSLOG_VERSION}.tar.gz
  URL_HASH SHA256=${RSYSLOG_HASH}
  CONFIGURE_COMMAND env "LIBESTR_LIBS=-L/lib64 -lestr" "LIBESTR_CFLAGS=-I/usr/include -I${STAGE_EMBEDDED_DIR}/include" "LDFLAGS=-L${STAGE_EMBEDDED_DIR}/lib -Wl,-rpath,${INSTALL_PREFIX_EMBEDDED}/lib,-rpath,${STAGE_EMBEDDED_DIR}/lib" <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --disable-liblogging-stdlog --enable-imptcp --enable-mmjsonparse --enable-mmutf8fix --enable-elasticsearch --enable-omkafka
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

#
# TrafficServer: HTTP caching server
#
ExternalProject_Add(
  trafficserver
  URL http://mirror.olnevhost.net/pub/apache/trafficserver/trafficserver-${TRAFFICSERVER_VERSION}.tar.bz2
  URL_HASH MD5=${TRAFFICSERVER_HASH}
  CONFIGURE_COMMAND env SPHINXBUILD=false LDFLAGS=-Wl,-rpath,${STAGE_EMBEDDED_DIR}/lib <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --enable-experimental-plugins
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    # Trim our own distribution by removing some larger files we don't need for
    # API Umbrella.
    COMMAND rm -f ${STAGE_EMBEDDED_DIR}/bin/traffic_sac
)

#
# LuaRock app dependencies
#
luarocks_install(lua-resty-http ${LUAROCK_RESTY_HTTP_VERSION})
luarocks_install(argparse ${LUAROCK_ARGPARSE_VERSION})
luarocks_install(inspect ${LUAROCK_INSPECT_VERSION})
luarocks_install(libcidr-ffi ${LUAROCK_LIBCIDR_VERSION} CIDR_DIR=${STAGE_EMBEDDED_DIR} libcidr)
luarocks_install(lua-cmsgpack ${LUAROCK_CMSGPACK_VERSION})
luarocks_install(lua-iconv ${LUAROCK_ICONV_VERSION})
luarocks_install(luaposix ${LUAROCK_LUAPOSIX_VERSION})
luarocks_install(luasocket ${LUAROCK_LUASOCKET_VERSION})
luarocks_install(luatz ${LUAROCK_LUATZ_VERSION})
luarocks_install(lustache ${LUAROCK_LUSTACHE_VERSION})
luarocks_install(lyaml ${LUAROCK_LYAML_VERSION})
luarocks_install(penlight ${LUAROCK_PENLIGHT_VERSION})

#
# Other Lua app dependencies (non-luarocks)
#
ExternalProject_Add(
  lua_resty_dns_cache
  URL https://github.com/hamishforbes/lua-resty-dns-cache/archive/${LUA_RESTY_DNS_CACHE_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_DNS_CACHE_HASH}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/dns/cache.lua ${VENDOR_LUA_DIR}/resty/dns/cache.lua
)

ExternalProject_Add(
  lua_resty_logger_socket
  URL https://github.com/cloudflare/lua-resty-logger-socket/archive/${LUA_RESTY_LOGGER_SOCKET_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_LOGGER_SOCKET_HASH}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/logger/socket.lua ${VENDOR_LUA_DIR}/resty/logger/socket.lua
)

ExternalProject_Add(
  lua_resty_shcache
  URL https://github.com/cloudflare/lua-resty-shcache/archive/${LUA_RESTY_SHCACHE_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_SHCACHE_HASH}
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/shcache.lua ${VENDOR_LUA_DIR}/shcache.lua
)

#
# api-umbrella-static-site: Example website content
#
ExternalProject_Add(
  api_umbrella_static_site
  DEPENDS bundler
  URL https://github.com/NREL/api-umbrella-static-site/archive/${API_UMBRELLA_STATIC_SITE_VERSION}.tar.gz
  URL_HASH MD5=${API_UMBRELLA_STATIC_SITE_HASH}
  BUILD_IN_SOURCE 1
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --path=<SOURCE_DIR>/vendor/bundle
    COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle exec middleman build
  INSTALL_COMMAND rm -rf ${STAGE_EMBEDDED_DIR}/apps/static-site/releases
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build
    COMMAND rsync -a <SOURCE_DIR>/build/ ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/static-site && ln -snf releases/${RELEASE_TIMESTAMP} ./current
)

#
# Test Environment
#

# Unbound: Local DNS server for testing DNS changes
ExternalProject_Add(
  unbound
  URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz
  URL_HASH SHA256=${UNBOUND_HASH}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>/test
  INSTALL_COMMAND make install
)

luarocks_install(luacheck ${LUAROCK_LUACHECK_VERSION})

add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/vendor/bundle
  DEPENDS bundler ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile.lock
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --clean --path=vendor/bundle
    COMMAND touch vendor/bundle
)
add_custom_target(web_app_bundle_install ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/vendor/bundle)

add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/tmp/web-assets
  DEPENDS web_app_bundle_install ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/**/*
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} DEVISE_SECRET_KEY=temp RAILS_SECRET_TOKEN=temp bundle exec rake assets:precompile
    COMMAND mkdir -p tmp/web-assets
    COMMAND rsync -a --delete-after public/web-assets/ tmp/web-assets/
    COMMAND rm -rf public/web-assets
    COMMAND touch tmp/web-assets
)
add_custom_target(web_app_assets_precompile ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/tmp/web-assets)

add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
  DEPENDS web_app_assets_precompile
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
	# Create a new release directory, copying the relevant source code from the
	# current repo checkout into the release (but excluding tests, etc).
  COMMAND rm -rf ${STAGE_EMBEDDED_DIR}/apps/core/releases
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
    COMMAND	rsync -a "--filter=:- ${CMAKE_SOURCE_DIR}/.gitignore" --include=/templates/etc/perp/.boot --exclude=.* --exclude=/templates/etc/test-env* --exclude=/templates/etc/perp/test-env* --exclude=/src/api-umbrella/web-app/spec --exclude=/src/api-umbrella/web-app/app/assets --exclude=/src/api-umbrella/hadoop-analytics --include=/bin/*** --include=/config/*** --include=/LICENSE.txt --include=/templates/*** --include=/src/*** --exclude=* ${CMAKE_SOURCE_DIR}/ ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core && ln -snf releases/${RELEASE_TIMESTAMP} ./current
    # Symlink the main api-umbrella binary into place.
    COMMAND mkdir -p ${STAGE_PREFIX_DIR}/bin
    COMMAND cd ${STAGE_PREFIX_DIR}/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella ./api-umbrella
    # Copy all of the vendor files into place.
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor
    #COMMAND rsync -a --delete-after $(VENDOR_DIR)/ ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP} && ln -snf ../../shared/vendor ./vendor
    # Copy the precompiled assets into place.
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/shared/src/api-umbrella/web-app/public/web-assets
    COMMAND rsync -a --delete-after ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/tmp/web-assets/ ${STAGE_EMBEDDED_DIR}/apps/core/shared/src/api-umbrella/web-app/public/web-assets/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/src/api-umbrella/web-app/public && ln -snf ../../../../../../shared/src/api-umbrella/web-app/public/web-assets ./web-assets
    # Re-run the bundle install inside the release directory, but disabling
    # non-production gem groups. Combined with the clean flag, this deletes all
    # the test/development/asset gems we don't need for a release.
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/src/api-umbrella/web-app && env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --path=../../../vendor/bundle --clean --without="development test assets" --deployment
    # Purge a bunch of content out of the bundler results to make for a lighter
    # release distribution. Purge gem caches, embedded test files, and
    # intermediate files used when compiling C gems from source. Also delete some
    # of the duplicate .so library files for C extensions (we should only need
    # the ones in the "extensions" directory, the rest are duplicates for legacy
    # purposes).
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor/bundle && rm -rf ruby/*/cache ruby/*/gems/*/test* ruby/*/gems/*/spec ruby/*/bundler/gems/*/test* ruby/*/bundler/gems/*/spec
    # Setup a shared symlink for web-app temp files.
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/shared/src/api-umbrella/web-app/tmp
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/src/api-umbrella/web-app && ln -snf ../../../../../shared/src/api-umbrella/web-app/tmp ./tmp
)
add_custom_target(core_release ALL DEPENDS ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP})


#
# Installation
#
install(
  DIRECTORY ${CMAKE_SOURCE_DIR}/build/cmake/dest/${CMAKE_INSTALL_PREFIX}/
  DESTINATION ${CMAKE_INSTALL_PREFIX}
  USE_SOURCE_PERMISSIONS
)
install(PROGRAMS ${CMAKE_SOURCE_DIR}/build/package/files/etc/init.d/api-umbrella DESTINATION /etc/init.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/logrotate.d/api-umbrella DESTINATION /etc/logrotate.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/sudoers.d/api-umbrella DESTINATION /etc/sudoers.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/api-umbrella/api-umbrella.yml DESTINATION /etc/api-umbrella RENAME api-umbrella.yml.default)

#
# Packaging
#
set(CPACK_PACKAGE_VERSION_MAJOR 0)
set(CPACK_PACKAGE_VERSION_MINOR 12)
set(CPACK_PACKAGE_VERSION_PATCH 0)
set(CPACK_RESOURCE_FILE_LICENSE ${CMAKE_SOURCE_DIR}/LICENSE.txt)

if(EXISTS "/etc/redhat-release")
  set(CPACK_GENERATOR RPM)
  set(CPACK_RPM_COMPRESSION_TYPE xz)
  #set(CPACK_RPM_PACKAGE_REQUIRES )
  set(CPACK_RPM_POST_INSTALL_SCRIPT_FILE ${CMAKE_SOURCE_DIR}/build/package/scripts/postinst)
  set(CPACK_RPM_PRE_UNINSTALL_SCRIPT_FILE ${CMAKE_SOURCE_DIR}/build/package/scripts/prerm)
  set(CPACK_RPM_POST_UNINSTALL_SCRIPT_FILE ${CMAKE_SOURCE_DIR}/build/package/scripts/postrm)
endif()

if(EXISTS "/etc/debian_version")
  set(CPACK_GENERATOR DEB)
  set(CPACK_DEBIAN_COMPRESSION_TYPE xz)
  set(
    CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
    ${CMAKE_SOURCE_DIR}/build/package/scripts/postinst
    ${CMAKE_SOURCE_DIR}/build/package/scripts/prerm
    ${CMAKE_SOURCE_DIR}/build/package/scripts/postrm
  )
endif()

include(CPack)
