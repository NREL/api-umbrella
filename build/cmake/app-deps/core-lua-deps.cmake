set(LUAROCK_ARGPARSE_VERSION 0.6.0-1)
set(LUAROCK_ARGPARSE_HASH 6656139dd66430075aa2093556857a84)
set(LUAROCK_CMSGPACK_VERSION 0.4.0-0)
set(LUAROCK_CMSGPACK_HASH f459d16fffdbbc85e582803321b3cec9)
set(LUAROCK_ICONV_VERSION 7-3)
set(LUAROCK_ICONV_HASH 138d21a895d267f09ff40fcb75324f74)
set(LUAROCK_INSPECT_VERSION 3.1.1-0)
set(LUAROCK_INSPECT_HASH 8a8a05f10b07a603e44e4f8b39bddd35)
set(LUAROCK_LUAPOSIX_VERSION 34.0.4-1)
set(LUAROCK_LUAPOSIX_HASH e584252902055ee40f250a1a304ec18e)
set(LUAROCK_LUSTACHE_VERSION 1.3.1-0)
set(LUAROCK_LUSTACHE_HASH 840ecd41bf19ed1751916de2cd46229e)
set(LUAROCK_LYAML_VERSION 6.2.2-1)
set(LUAROCK_LYAML_HASH d8c8c11db09bfc3f82838d0195d7cf04)
set(LUAROCK_PENLIGHT_VERSION 1.5.4-1)
set(LUAROCK_PENLIGHT_HASH 8f4e6b4c7e851c28cb3e95be728d6507)
set(LUAROCK_RESTY_UUID_VERSION 1.1-1)
set(LUAROCK_RESTY_UUID_HASH d14ae99d6f18edd5c934e6050e974c5e)
set(LUA_LUASOCKET_VERSION 652959890943c34d7180cae372339b91e62f0d7b)
set(LUA_LUASOCKET_HASH 6b3e3bdf60267f5957c2ea44e563ed70)
set(LUA_RESTY_LOGGER_SOCKET_VERSION 15cc1c256e55b8e68ec9b220b6883c227a763d4e)
set(LUA_RESTY_LOGGER_SOCKET_HASH efe14697a8c4be612c011f54fce06191)
set(LUA_RESTY_SHCACHE_VERSION fb2e275c2cdca08eaa34a7b73375e41ac3eff200)
set(LUA_RESTY_SHCACHE_HASH 5d3cbcf8fbad1954cdcb3826afa41afe)
set(OPM_ICU_DATE_VERSION 857990ba72cf48f7ae20dfb861a783231b5a2e79)
set(OPM_ICU_DATE_HASH 580f4a650782556266cc341630d39f63)
set(OPM_LIBCIDR_VERSION 0.1.3)
set(OPM_LIBCIDR_HASH 9d995b83a7d857fcdec949725711b784)
set(OPM_RESTY_HTTP_VERSION 0.12)
set(OPM_RESTY_HTTP_HASH edc5d6deb82c1f5f628e382290c79209)
set(OPM_RESTY_TXID_VERSION 1.0.0)
set(OPM_RESTY_TXID_HASH 0c2ebfef460d537316e52f696d8bbfb7)

# LuaRock app dependencies
luarocks_install(argparse ${LUAROCK_ARGPARSE_VERSION} ${LUAROCK_ARGPARSE_HASH})
luarocks_install(inspect ${LUAROCK_INSPECT_VERSION} ${LUAROCK_INSPECT_HASH})
luarocks_install(lua-cmsgpack ${LUAROCK_CMSGPACK_VERSION} ${LUAROCK_CMSGPACK_HASH})
luarocks_install(lua-iconv ${LUAROCK_ICONV_VERSION} ${LUAROCK_ICONV_HASH})
luarocks_install(lua-resty-uuid ${LUAROCK_RESTY_UUID_VERSION} ${LUAROCK_RESTY_UUID_HASH})
luarocks_install(luaposix ${LUAROCK_LUAPOSIX_VERSION} ${LUAROCK_LUAPOSIX_HASH})
luarocks_install(lustache ${LUAROCK_LUSTACHE_VERSION} ${LUAROCK_LUSTACHE_HASH})
luarocks_install(lyaml ${LUAROCK_LYAML_VERSION} ${LUAROCK_LYAML_HASH})
luarocks_install(penlight ${LUAROCK_PENLIGHT_VERSION} ${LUAROCK_PENLIGHT_HASH})

# OPM app dependencies
opm_install(lua-libcidr-ffi GUI ${OPM_LIBCIDR_VERSION} ${OPM_LIBCIDR_HASH} libcidr)
opm_install(lua-resty-http pintsized ${OPM_RESTY_HTTP_VERSION} ${OPM_RESTY_HTTP_HASH})
opm_install(lua-resty-txid GUI ${OPM_RESTY_TXID_VERSION} ${OPM_RESTY_TXID_HASH})

ExternalProject_Add(
  opm_lua-icu-date
  EXCLUDE_FROM_ALL 1
  DEPENDS luarocks
  URL https://github.com/GUI/lua-icu-date/archive/${OPM_ICU_DATE_VERSION}.tar.gz
  URL_HASH MD5=${OPM_ICU_DATE_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ${LUAROCKS_CMD} --tree=${VENDOR_DIR} make --local icu-date-git-1.rockspec
)

# Other Lua app dependencies (non-luarocks)
ExternalProject_Add(
  lua_luasocket_url
  EXCLUDE_FROM_ALL 1
  DEPENDS luarocks
  URL https://github.com/diegonehab/luasocket/archive/${LUA_LUASOCKET_VERSION}.tar.gz
  URL_HASH MD5=${LUA_LUASOCKET_HASH}
  # Just install the URL parsing library from luasocket (rather than the whole
  # luarocks, since we don't need the other parts, and the luarock is somewhat
  # outdated). In order to just install this one file, patch it to work without
  # the base luasocket library present (it doesn't actually use the base stuff
  # for anything).
  PATCH_COMMAND sed -i -e "s%local socket = require.*%local socket = {}%" src/url.lua
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/src/url.lua ${VENDOR_LUA_DIR}/socket/url.lua
)

ExternalProject_Add(
  lua_resty_logger_socket
  EXCLUDE_FROM_ALL 1
  DEPENDS luarocks
  URL https://github.com/cloudflare/lua-resty-logger-socket/archive/${LUA_RESTY_LOGGER_SOCKET_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_LOGGER_SOCKET_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/logger/socket.lua ${VENDOR_LUA_DIR}/resty/logger/socket.lua
)

ExternalProject_Add(
  lua_resty_shcache
  EXCLUDE_FROM_ALL 1
  DEPENDS luarocks
  URL https://github.com/cloudflare/lua-resty-shcache/archive/${LUA_RESTY_SHCACHE_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_SHCACHE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/shcache.lua ${VENDOR_LUA_DIR}/shcache.lua
)

set(
  LUA_DEPS
  lua_luasocket_url
  lua_resty_logger_socket
  lua_resty_shcache
  luarock_argparse
  luarock_inspect
  luarock_lua-cmsgpack
  luarock_lua-iconv
  luarock_lua-resty-uuid
  luarock_luaposix
  luarock_lustache
  luarock_lyaml
  luarock_penlight
  opm_lua-icu-date
  opm_lua-libcidr-ffi
  opm_lua-resty-http
  opm_lua-resty-txid
)

# Also depend on the internal stamp files used by ExternalProject_Add, since
# add_custom_command seems to require files to properly work when updates
# occur (we can't just specify the ExternalProject_Add target names or
# updates aren't detected). But we still need to depend on the project names
# directly for the initial install dependency ordering.
foreach(LUA_DEP ${LUA_DEPS})
  list(APPEND LUA_DEPS_DEPENDS ${LUA_DEP})
  list(APPEND LUA_DEPS_DEPENDS ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${LUA_DEP}-complete)
endforeach()

add_custom_command(
  OUTPUT ${STAMP_DIR}/core-lua-deps
  DEPENDS ${LUA_DEPS_DEPENDS}
  COMMAND touch ${STAMP_DIR}/core-lua-deps
)
