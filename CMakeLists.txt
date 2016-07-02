cmake_minimum_required(VERSION 2.8.10 FATAL_ERROR)
project(api-umbrella)

option(ENABLE_HADOOP_ANALYTICS "Build dependencies for Hadoop analytics" off)
option(ENABLE_TEST_DEPENDENCIES "Build dependencies for running tests" off)

# Installation prefix
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX /opt/api-umbrella CACHE PATH "default install path" FORCE)
endif()
set(INSTALL_PREFIX_EMBEDDED ${CMAKE_INSTALL_PREFIX}/embedded)

# Where to install cmake ExternalProjects.
set(EP_PREFIX build/work)
set_directory_properties(PROPERTIES EP_PREFIX ${EP_PREFIX})
set(WORK_DIR ${CMAKE_BINARY_DIR}/${EP_PREFIX})

# Directory to store "stamp" files indicating when a step was completed or last
# touched.
set(STAMP_DIR ${WORK_DIR}/stamp)
execute_process(COMMAND mkdir -p ${STAMP_DIR})

# Where to stage installations during "make" phase.
set(STAGE_DIR ${WORK_DIR}/stage)
set(STAGE_PREFIX_DIR ${STAGE_DIR}${CMAKE_INSTALL_PREFIX})
set(STAGE_EMBEDDED_DIR ${STAGE_DIR}${INSTALL_PREFIX_EMBEDDED})
set(HADOOP_ANALYTICS_STAGE_DIR ${WORK_DIR}/stage-hadoop-analytics)
set(HADOOP_ANALYTICS_STAGE_PREFIX_DIR ${HADOOP_ANALYTICS_STAGE_DIR}${CMAKE_INSTALL_PREFIX})
set(HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR ${HADOOP_ANALYTICS_STAGE_DIR}${INSTALL_PREFIX_EMBEDDED})

# Where to install app-level vendor dependencies.
set(VENDOR_DIR ${WORK_DIR}/vendor)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
set(LUAROCKS_CMD env LUA_PATH=${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?.lua$<SEMICOLON>${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?/init.lua$<SEMICOLON>$<SEMICOLON> ${STAGE_EMBEDDED_DIR}/bin/luarocks)

# Where to install test-only dependencies.
set(TEST_INSTALL_PREFIX ${WORK_DIR}/test-env)
set(TEST_VENDOR_DIR ${TEST_INSTALL_PREFIX}/vendor)
set(TEST_VENDOR_LUA_SHARE_DIR ${TEST_VENDOR_DIR}/share/lua/5.1)
set(TEST_VENDOR_LUA_LIB_DIR ${TEST_VENDOR_DIR}/lib/lua/5.1)

# Define a timestamped release name for our app installations.
execute_process(COMMAND date -u +%Y%m%d%H%M%S OUTPUT_VARIABLE RELEASE_TIMESTAMP OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND date -u +%Y%m%d OUTPUT_VARIABLE RELEASE_DATE OUTPUT_STRIP_TRAILING_WHITESPACE)

include(ExternalProject)

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

include(${CMAKE_SOURCE_DIR}/build/cmake/versions.cmake)
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
if(ENABLE_HADOOP_ANALYTICS)
  include(${CMAKE_SOURCE_DIR}/build/cmake/hadoop-analytics/flume.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/hadoop-analytics/kylin.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/hadoop-analytics/presto.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/hadoop-analytics/processor.cmake)
endif()

#
# Testing
#
if(ENABLE_TEST_DEPENDENCIES)
  include(${CMAKE_SOURCE_DIR}/build/cmake/test/unbound.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/test/mongo-orchestration.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/test/lua-deps.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/test/shellcheck.cmake)
endif()
include(${CMAKE_SOURCE_DIR}/build/cmake/test/lint.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test/test-proxy.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test/test-web-app.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test/test.cmake)

#
# Installation
#
include(${CMAKE_SOURCE_DIR}/build/cmake/install.cmake)

#
# Packaging
#
include(${CMAKE_SOURCE_DIR}/build/cmake/package.cmake)

#
# Clean Task
#
include(${CMAKE_SOURCE_DIR}/build/cmake/clean-download-archives.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/distclean.cmake)

#
# Outdated Dependencies Check
#
include(${CMAKE_SOURCE_DIR}/build/cmake/outdated.cmake)
