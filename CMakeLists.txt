cmake_minimum_required(VERSION 3.6.0 FATAL_ERROR)
project(api-umbrella)

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

# Where to install development-only dependencies.
set(DEV_INSTALL_PREFIX ${WORK_DIR}/dev-env)
set(DEV_VENDOR_DIR ${DEV_INSTALL_PREFIX}/vendor)

# Where to install test-only dependencies.
set(TEST_INSTALL_PREFIX ${WORK_DIR}/test-env)
set(TEST_VENDOR_DIR ${TEST_INSTALL_PREFIX}/vendor)
set(TEST_VENDOR_LUA_SHARE_DIR ${TEST_VENDOR_DIR}/share/lua/5.1)
set(TEST_VENDOR_LUA_LIB_DIR ${TEST_VENDOR_DIR}/lib/lua/5.1)

# PATH variables to use when executing other commands. Note that we use a
# hard-coded base default path (instead of $ENV{PATH}), since using $ENV{PATH}
# makes cmake think there have been PATH changes which trigger rebuilds, even
# when the path hasn't changed.
set(DEFAULT_PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin)
set(STAGE_EMBEDDED_PATH ${STAGE_EMBEDDED_DIR}/bin:${DEFAULT_PATH})
set(DEV_PATH ${DEV_INSTALL_PREFIX}/bin:${STAGE_EMBEDDED_PATH})

# Where to install app-level vendor dependencies.
set(VENDOR_DIR ${WORK_DIR}/vendor)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
if(ENABLE_DEPLOY_ONLY)
  set(LUA_PREFIX ${INSTALL_PREFIX_EMBEDDED})
else()
  set(LUA_PREFIX ${STAGE_EMBEDDED_DIR})
endif()
set(LUAROCKS_CMD env LUA_PATH=${LUA_PREFIX}/openresty/luajit/share/lua/5.1/?.lua$<SEMICOLON>${LUA_PREFIX}/openresty/luajit/share/lua/5.1/?/init.lua$<SEMICOLON>$<SEMICOLON> ${LUA_PREFIX}/bin/luarocks)
set(OPM_CMD env LUA_PATH=${LUA_PREFIX}/openresty/lualib/?.lua$<SEMICOLON>${LUA_PREFIX}/openresty/lualib/?/init.lua$<SEMICOLON>$<SEMICOLON> PATH=${STAGE_EMBEDDED_PATH} LD_LIBRARY_PATH=${STAGE_EMBEDDED_DIR}/openresty/luajit/lib:${STAGE_EMBEDDED_DIR}/lib opm)

# Misc dependencies/functions.
include(ExternalProject)
find_package(PkgConfig REQUIRED)
include(${CMAKE_SOURCE_DIR}/build/cmake/functions/GetGitRevisionDescription.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/functions/GetGitTimestamp.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/functions/luarocks_install.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/functions/opm_install.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/functions/require_program.cmake)

# make deps
include(${CMAKE_SOURCE_DIR}/build/cmake/deps.cmake)

# make build-deps
include(${CMAKE_SOURCE_DIR}/build/cmake/build-deps.cmake OPTIONAL)

# make app-deps
include(${CMAKE_SOURCE_DIR}/build/cmake/app-deps.cmake OPTIONAL)

# make app
include(${CMAKE_SOURCE_DIR}/build/cmake/app.cmake OPTIONAL)

# make test-deps
include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps.cmake OPTIONAL)

# make test-bundle
include(${CMAKE_SOURCE_DIR}/build/cmake/test-bundle.cmake OPTIONAL)

# make test
include(${CMAKE_SOURCE_DIR}/build/cmake/test.cmake OPTIONAL)

# make distclean
include(${CMAKE_SOURCE_DIR}/build/cmake/distclean.cmake OPTIONAL)

# make install
include(${CMAKE_SOURCE_DIR}/build/cmake/install.cmake OPTIONAL)

# make package
include(${CMAKE_SOURCE_DIR}/build/cmake/package.cmake OPTIONAL)
