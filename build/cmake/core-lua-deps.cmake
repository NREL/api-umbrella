# LuaRock app dependencies
luarocks_install(argparse ${LUAROCK_ARGPARSE_VERSION})
luarocks_install(inspect ${LUAROCK_INSPECT_VERSION})
luarocks_install(libcidr-ffi ${LUAROCK_LIBCIDR_VERSION} CIDR_DIR=${STAGE_EMBEDDED_DIR} libcidr)
luarocks_install(lua-cmsgpack ${LUAROCK_CMSGPACK_VERSION})
luarocks_install(lua-iconv ${LUAROCK_ICONV_VERSION})
luarocks_install(lua-resty-auto-ssl ${LUAROCK_RESTY_AUTO_SSL_VERSION})
luarocks_install(lua-resty-http ${LUAROCK_RESTY_HTTP_VERSION})
luarocks_install(lua-resty-uuid ${LUAROCK_RESTY_UUID_VERSION})
luarocks_install(luaposix ${LUAROCK_LUAPOSIX_VERSION})
luarocks_install(luasocket ${LUAROCK_LUASOCKET_VERSION})
luarocks_install(luatz ${LUAROCK_LUATZ_VERSION})
luarocks_install(lustache ${LUAROCK_LUSTACHE_VERSION})
luarocks_install(lyaml ${LUAROCK_LYAML_VERSION})
luarocks_install(penlight ${LUAROCK_PENLIGHT_VERSION})

# Other Lua app dependencies (non-luarocks)
ExternalProject_Add(
  lua_resty_dns_cache
  URL https://github.com/hamishforbes/lua-resty-dns-cache/archive/${LUA_RESTY_DNS_CACHE_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_DNS_CACHE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/dns/cache.lua ${VENDOR_LUA_DIR}/resty/dns/cache.lua
)

ExternalProject_Add(
  lua_resty_logger_socket
  URL https://github.com/cloudflare/lua-resty-logger-socket/archive/${LUA_RESTY_LOGGER_SOCKET_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_LOGGER_SOCKET_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/logger/socket.lua ${VENDOR_LUA_DIR}/resty/logger/socket.lua
)

ExternalProject_Add(
  lua_resty_shcache
  URL https://github.com/cloudflare/lua-resty-shcache/archive/${LUA_RESTY_SHCACHE_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_SHCACHE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/shcache.lua ${VENDOR_LUA_DIR}/shcache.lua
)

add_custom_command(
  OUTPUT ${STAMP_DIR}/core-lua-deps
  # Depend on the internal stamp files used by ExternalProject_Add, since
  # add_custom_command seems to require files to properly work when updates
  # occur (we can't just specify the ExternalProject_Add target names or
  # updates aren't detected).
  DEPENDS
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_argparse-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_inspect-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_libcidr-ffi-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_lua-cmsgpack-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_lua-iconv-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_lua-resty-auto-ssl-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_lua-resty-http-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_lua-resty-uuid-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_luaposix-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_luasocket-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_luatz-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_lustache-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_lyaml-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/luarock_penlight-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/lua_resty_dns_cache-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/lua_resty_logger_socket-complete
    ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/lua_resty_shcache-complete
  COMMAND touch ${STAMP_DIR}/core-lua-deps
)
