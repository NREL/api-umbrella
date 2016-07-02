cmake_minimum_required(VERSION 2.8.10 FATAL_ERROR)

# A simplified cmake file that only tries to install the lua dependencies
# needed during a capistrano deployment (when overlaying on top of an package
# install).

if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX /opt/api-umbrella CACHE PATH "default install path" FORCE)
endif()
set(INSTALL_PREFIX_EMBEDDED ${CMAKE_INSTALL_PREFIX}/embedded)
set(EP_PREFIX work)
set_directory_properties(PROPERTIES EP_PREFIX ${EP_PREFIX})
set(WORK_DIR ${CMAKE_BINARY_DIR}/${EP_PREFIX})
set(STAMP_DIR ${WORK_DIR}/stamp)
execute_process(COMMAND mkdir -p ${STAMP_DIR})
set(VENDOR_DIR ${WORK_DIR}/vendor)
set(VENDOR_LUA_DIR ${VENDOR_DIR}/share/lua/5.1)
set(STAGE_EMBEDDED_DIR ${INSTALL_PREFIX_EMBEDDED})
set(LUAROCKS_CMD env LUA_PATH=${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?.lua$<SEMICOLON>${STAGE_EMBEDDED_DIR}/openresty/luajit/share/lua/5.1/?/init.lua$<SEMICOLON>$<SEMICOLON> ${STAGE_EMBEDDED_DIR}/bin/luarocks)

include(ExternalProject)

function(luarocks_install package version)
  ExternalProject_Add(
    luarock_${package}
    DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://luarocks.org/${package}-${version}.rockspec
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${LUAROCKS_CMD} --tree=${VENDOR_DIR} install ${package} ${version} ${ARGV2}
  )
endfunction()

include(${CMAKE_SOURCE_DIR}/../versions.cmake)
include(${CMAKE_SOURCE_DIR}/../core-lua-deps.cmake)

add_custom_target(
  install-core-lua-deps
  DEPENDS ${STAMP_DIR}/core-lua-deps
  COMMAND rsync -av ${VENDOR_DIR}/ ${INSTALL_PREFIX_EMBEDDED}/apps/core/shared/vendor/
)
