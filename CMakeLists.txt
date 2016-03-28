cmake_minimum_required(VERSION 2.8.10 FATAL_ERROR)
project(api-umbrella)

# Installation prefix
set(CMAKE_INSTALL_PREFIX /opt/api-umbrella)
set(INSTALL_PREFIX_EMBEDDED ${CMAKE_INSTALL_PREFIX}/embedded)

# Where to install cmake ExternalProjects.
set(EP_PREFIX build/work)
set_directory_properties(PROPERTIES EP_PREFIX ${EP_PREFIX})
set(WORK_DIR ${CMAKE_SOURCE_DIR}/${EP_PREFIX})

# Where to stage installations during "make" phase.
set(STAGE_DIR ${WORK_DIR}/stage)
set(STAGE_PREFIX_DIR ${STAGE_DIR}${CMAKE_INSTALL_PREFIX})
set(STAGE_EMBEDDED_DIR ${STAGE_DIR}${INSTALL_PREFIX_EMBEDDED})

# Where to install app-level vendor dependencies.
set(VENDOR_DIR ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
set(LUAROCKS_CMD env LUA_PATH=${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?.lua$<SEMICOLON>${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?/init.lua$<SEMICOLON>$<SEMICOLON> ${STAGE_EMBEDDED_DIR}/bin/luarocks)

# Where to install test-only dependencies.
set(TEST_INSTALL_PREFIX ${WORK_DIR}/test-env)
set(TEST_VENDOR_DIR ${TEST_INSTALL_PREFIX}/vendor)
set(TEST_VENDOR_LUA_SHARE_DIR ${TEST_VENDOR_DIR}/share/lua/5.1)
set(TEST_VENDOR_LUA_LIB_DIR ${TEST_VENDOR_DIR}/lib/lua/5.1)

# Define a timestamped release name for our app installations.
execute_process(COMMAND date -u +%Y%m%d%H%M%S OUTPUT_VARIABLE RELEASE_TIMESTAMP OUTPUT_STRIP_TRAILING_WHITESPACE)

include(ExternalProject)

# Define the versions of the various dependencies to build.
set(API_UMBRELLA_STATIC_SITE_VERSION 265714dbee04efa14f4d83e1f78f06ec492d9c6e)
set(API_UMBRELLA_STATIC_SITE_HASH 500d14f7417bee84169b2591f2d7722f)
set(BUNDLER_VERSION 1.11.2)
set(ELASTICSEARCH_VERSION 1.7.5)
set(ELASTICSEARCH_HASH 23353fcfdf4897997eb36624afa0af62562f9b3c)
set(GLIDE_VERSION 0.10.1)
set(GLIDE_HASH b738e5c25f51c638313a9532ebb22f33)
set(GOLANG_VERSION 1.5.3)
set(GOLANG_HASH 43afe0c5017e502630b1aea4d44b8a7f059bf60d7f29dfd58db454d4e4e0ae53)
# Newer version from git fixes https://github.com/json-c/json-c/issues/159
set(JSON_C_VERSION 8ba19375d53347d08b82efef609ff352eefa9093)
set(JSON_C_HASH 4433374ec51ae8188fa860914a8fe67d)
set(LIBCIDR_VERSION 1.2.3)
set(LIBCIDR_HASH c5efcc7ae114fdaa5583f58dacecd9de)
set(LIBESTR_VERSION 0.1.10)
set(LIBESTR_HASH bd655e126e750edd18544b88eb1568d200a424a0c23f665eb14bbece07ac703c)
set(LIBGEOIP_VERSION 1.6.9)
set(LIBGEOIP_HASH 7475942dc8155046dddb4846f587a7e6)
# Hold at 0.8 - 0.9 doesn't seem to be compatible with rsyslog.
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
# Hold at rsyslog 8.14.0 until ElasticSearch issues are fixed (hopefully 8.18):
# https://github.com/rsyslog/rsyslog/issues/748
set(RSYSLOG_VERSION 8.14.0)
set(RSYSLOG_HASH 443b5b1d2b84f5cd429d06d230af7fb2352336fa6449cb6484dbd4418a7ae7c2)
set(RUNIT_VERSION 2.1.2)
set(RUNIT_HASH 6c985fbfe3a34608eb3c53dc719172c4)
# Don't move to TrafficServer 6 until we can verify keepalive behavior:
# https://issues.apache.org/jira/browse/TS-3959
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

include(${CMAKE_SOURCE_DIR}/build/cmake/elasticsearch.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/libcidr.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/libgeoip.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/mongodb.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/mora.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/openresty.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/luarocks.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/perp.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/runit_svlogd.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/ruby.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/rsyslog.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/trafficserver.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/static-site.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/core-lua-deps.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/core-web-app.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/core.cmake)

#
# Testing
#
include(${CMAKE_SOURCE_DIR}/build/cmake/test/unbound.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test/mongo-orchestration.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test/lua-deps.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test/lint.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test/npm-test.cmake)

#
# Installation
#
include(${CMAKE_SOURCE_DIR}/build/cmake/install.cmake)

#
# Packaging
#
include(${CMAKE_SOURCE_DIR}/build/cmake/package.cmake)
