include(${CMAKE_SOURCE_DIR}/build/cmake/luarocks_install.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/opm_install.cmake)

# LuaRock app dependencies
luarocks_install(argparse ${LUAROCK_ARGPARSE_VERSION} ${LUAROCK_ARGPARSE_HASH})
luarocks_install(bcrypt ${LUAROCK_BCRYPT_VERSION} ${LUAROCK_BCRYPT_HASH})
luarocks_install(inspect ${LUAROCK_INSPECT_VERSION} ${LUAROCK_INSPECT_HASH})
luarocks_install(lua-cmsgpack ${LUAROCK_CMSGPACK_VERSION} ${LUAROCK_CMSGPACK_HASH})
luarocks_install(lua-iconv ${LUAROCK_ICONV_VERSION} ${LUAROCK_ICONV_HASH})
luarocks_install(lua-resty-auto-ssl ${LUAROCK_RESTY_AUTO_SSL_VERSION} ${LUAROCK_RESTY_AUTO_SSL_HASH})
luarocks_install(lua-resty-uuid ${LUAROCK_RESTY_UUID_VERSION} ${LUAROCK_RESTY_UUID_HASH})
luarocks_install(luaposix ${LUAROCK_LUAPOSIX_VERSION} ${LUAROCK_LUAPOSIX_HASH})
luarocks_install(luatz ${LUAROCK_LUATZ_VERSION} ${LUAROCK_LUATZ_HASH})
luarocks_install(lustache ${LUAROCK_LUSTACHE_VERSION} ${LUAROCK_LUSTACHE_HASH})
luarocks_install(lyaml ${LUAROCK_LYAML_VERSION} ${LUAROCK_LYAML_HASH})
luarocks_install(penlight ${LUAROCK_PENLIGHT_VERSION} ${LUAROCK_PENLIGHT_HASH})

# OPM app dependencies
opm_install(lua-libcidr-ffi GUI ${OPM_LIBCIDR_VERSION} ${OPM_LIBCIDR_HASH} libcidr)
opm_install(lua-resty-http pintsized ${OPM_RESTY_HTTP_VERSION} ${OPM_RESTY_HTTP_HASH})
opm_install(lua-resty-mail GUI ${OPM_RESTY_MAIL_VERSION} ${OPM_RESTY_MAIL_HASH})
opm_install(lua-resty-nettle bungle ${OPM_RESTY_NETTLE_VERSION} ${OPM_RESTY_NETTLE_HASH})
opm_install(lua-resty-session bungle ${OPM_RESTY_SESSION_VERSION} ${OPM_RESTY_SESSION_HASH})
opm_install(lua-resty-validation bungle ${OPM_RESTY_VALIDATION_VERSION} ${OPM_RESTY_VALIDATION_HASH})

ExternalProject_Add(
  luarock_lapis
  DEPENDS luarocks
  URL https://github.com/leafo/lapis/archive/v${LUAROCK_LAPIS_VERSION}.tar.gz
  URL_HASH MD5=${LUAROCK_LAPIS_HASH}
  BUILD_IN_SOURCE 1
  # Patch to fix Lapis dependencies being broken under newer versions of
  # OpenResty: https://github.com/leafo/lapis/issues/539
  PATCH_COMMAND sed -i -e "s%\"lua-cjson\",%%" lapis-dev-1.rockspec
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ${LUAROCKS_CMD} --tree=${VENDOR_DIR} make --local lapis-dev-1.rockspec
)

# Other Lua app dependencies (non-luarocks)
ExternalProject_Add(
  lua_luasocket_url
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
  lua_resty_dns_cache
  DEPENDS luarocks
  URL https://github.com/hamishforbes/lua-resty-dns-cache/archive/${LUA_RESTY_DNS_CACHE_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_DNS_CACHE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/dns/cache.lua ${VENDOR_LUA_DIR}/resty/dns/cache.lua
)

ExternalProject_Add(
  lua_resty_gettext
  DEPENDS luarocks
  URL https://github.com/bungle/lua-resty-gettext/archive/${LUA_RESTY_GETTEXT_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_GETTEXT_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/gettext.lua ${VENDOR_LUA_DIR}/resty/gettext.lua
)

ExternalProject_Add(
  lua_resty_logger_socket
  DEPENDS luarocks
  URL https://github.com/cloudflare/lua-resty-logger-socket/archive/${LUA_RESTY_LOGGER_SOCKET_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_LOGGER_SOCKET_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/logger/socket.lua ${VENDOR_LUA_DIR}/resty/logger/socket.lua
)

ExternalProject_Add(
  lua_resty_shcache
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
  lua_resty_dns_cache
  lua_resty_gettext
  lua_resty_logger_socket
  lua_resty_shcache
  luarock_argparse
  luarock_bcrypt
  luarock_inspect
  luarock_lapis
  luarock_lua-cmsgpack
  luarock_lua-iconv
  luarock_lua-resty-auto-ssl
  luarock_lua-resty-uuid
  luarock_luaposix
  luarock_luatz
  luarock_lustache
  luarock_lyaml
  luarock_penlight
  opm_lua-libcidr-ffi
  opm_lua-resty-http
  opm_lua-resty-mail
  opm_lua-resty-nettle
  opm_lua-resty-session
  opm_lua-resty-validation
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
