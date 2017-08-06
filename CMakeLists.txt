cmake_minimum_required(VERSION 3.6.0 FATAL_ERROR)
project(api-umbrella)

option(ENABLE_HADOOP_ANALYTICS "Build dependencies for Hadoop analytics" off)
option(ENABLE_TEST_DEPENDENCIES "Build dependencies for running tests" off)
option(ENABLE_DEPLOY_ONLY "Only build dependencies for a deployment overlaying an existing package install" off)

# Installation prefix
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX /opt/api-umbrella CACHE PATH "default install path" FORCE)
endif()
set(INSTALL_PREFIX_EMBEDDED ${CMAKE_INSTALL_PREFIX}/embedded)

# Where to install cmake ExternalProjects.
set(EP_BASE build/work/external-projects)
set_directory_properties(PROPERTIES EP_BASE ${EP_BASE})
set(WORK_DIR ${CMAKE_BINARY_DIR}/build/work)
set(PACKAGE_WORK_DIR ${CMAKE_BINARY_DIR}/build/package/work)

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
if(ENABLE_DEPLOY_ONLY)
  set(LUA_PREFIX ${INSTALL_PREFIX_EMBEDDED})
else()
  set(LUA_PREFIX ${STAGE_EMBEDDED_DIR})
endif()
set(LUAROCKS_CMD env LUA_PATH=${LUA_PREFIX}/openresty/luajit/share/lua/5.1/?.lua$<SEMICOLON>${LUA_PREFIX}/openresty/luajit/share/lua/5.1/?/init.lua$<SEMICOLON>$<SEMICOLON> ${LUA_PREFIX}/bin/luarocks)

# Where to install development-only dependencies.
set(DEV_INSTALL_PREFIX ${WORK_DIR}/dev-env)
set(DEV_VENDOR_DIR ${DEV_INSTALL_PREFIX}/vendor)

# Where to install test-only dependencies.
set(TEST_INSTALL_PREFIX ${WORK_DIR}/test-env)
set(TEST_VENDOR_DIR ${TEST_INSTALL_PREFIX}/vendor)
set(TEST_VENDOR_LUA_SHARE_DIR ${TEST_VENDOR_DIR}/share/lua/5.1)
set(TEST_VENDOR_LUA_LIB_DIR ${TEST_VENDOR_DIR}/lib/lua/5.1)

# Define a timestamped release name for our app installations. Base this on the
# last git commit timestamp so installs are consistent for each git commit.
include(${CMAKE_SOURCE_DIR}/build/cmake/GetGitRevisionDescription.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/GetGitTimestamp.cmake)
get_git_timestamp(RELEASE_TIMESTAMP)
string(SUBSTRING ${RELEASE_TIMESTAMP} 0 8 RELEASE_DATE)

include(ExternalProject)

function(require_program name)
  find_program(${name} ${name})
  if(NOT ${name})
    MESSAGE(FATAL_ERROR "Could not find ${name}")
  endif()
endfunction(require_program)

if(ENABLE_DEPLOY_ONLY)
  # Create stub/empty targets for things the core build process depends on. But
  # for deploy-based builds, we'll assume these dependencies have already been
  # installed (since we're assuming the deploys are overlaying a package
  # installation).
  add_custom_target(bundler)
  add_custom_target(libcidr)
  add_custom_target(luarocks)

  include(${CMAKE_SOURCE_DIR}/build/cmake/versions.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/core.cmake)
else()
  find_package(LibXml2 REQUIRED)
  find_package(PkgConfig REQUIRED)
  pkg_search_module(LIBUUID REQUIRED uuid)
  pkg_search_module(LIBFFI REQUIRED libffi)
  require_program(rsync)

  include(${CMAKE_SOURCE_DIR}/build/cmake/versions.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/elasticsearch.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/emailrelay.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/libcidr.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/libgeoip.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/openresty.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/luarocks.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/perp.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/postgresql.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/runit_svlogd.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/rsyslog.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/trafficserver.cmake)
  include(${CMAKE_SOURCE_DIR}/build/cmake/static-site.cmake)
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
    include(${CMAKE_SOURCE_DIR}/build/cmake/test/lua-deps.cmake)
    include(${CMAKE_SOURCE_DIR}/build/cmake/test/mailhog.cmake)
    include(${CMAKE_SOURCE_DIR}/build/cmake/test/openldap.cmake)
    include(${CMAKE_SOURCE_DIR}/build/cmake/test/phantomjs.cmake)
    include(${CMAKE_SOURCE_DIR}/build/cmake/test/shellcheck.cmake)
    include(${CMAKE_SOURCE_DIR}/build/cmake/test/unbound.cmake)
  endif()
  include(${CMAKE_SOURCE_DIR}/build/cmake/test/bundle.cmake)
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
endif()
