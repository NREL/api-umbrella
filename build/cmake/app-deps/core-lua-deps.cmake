set(LUAROCK_ARGPARSE_VERSION 0.5.0-1)
set(LUAROCK_ARGPARSE_HASH 02db647a5521809390b101a741cca4ff)
set(LUAROCK_BCRYPT_VERSION 2.1-4)
set(LUAROCK_BCRYPT_HASH cc41d7f136fc51190bee6958d065e741)
set(LUAROCK_CMSGPACK_VERSION 0.4.0-0)
set(LUAROCK_CMSGPACK_HASH f459d16fffdbbc85e582803321b3cec9)
set(LUAROCK_ICONV_VERSION 7-1)
set(LUAROCK_ICONV_HASH 975fc133569249feaf76b000e112c437)
set(LUAROCK_INSPECT_VERSION 3.1.0-1)
set(LUAROCK_INSPECT_HASH 50c0f238a459ec3ef9d880faf4613689)
set(LUAROCK_LAPIS_VERSION 1.6.0)
set(LUAROCK_LAPIS_HASH bca0f43497f209446302ad105a11bea1)
set(LUAROCK_LUALDAP_VERSION 1.2.3-1)
set(LUAROCK_LUALDAP_HASH 3ed31efd579ab41d2aedf2a756427d62)
set(LUAROCK_LUAPOSIX_VERSION 34.0.1-3)
set(LUAROCK_LUAPOSIX_HASH 519a7b7b907baa73a138ffb65491e866)
set(LUAROCK_LUSTACHE_VERSION 1.3.1-0)
set(LUAROCK_LUSTACHE_HASH 840ecd41bf19ed1751916de2cd46229e)
set(LUAROCK_LYAML_VERSION 6.1.3-1)
set(LUAROCK_LYAML_HASH f4a7a8cd576389415de8c7b5eb586522)
set(LUAROCK_PENLIGHT_VERSION 1.5.4-1)
set(LUAROCK_PENLIGHT_HASH 8f4e6b4c7e851c28cb3e95be728d6507)
set(LUAROCK_RESTY_UUID_VERSION 1.1-1)
set(LUAROCK_RESTY_UUID_HASH d14ae99d6f18edd5c934e6050e974c5e)
set(LUA_LUASOCKET_VERSION 88b13a825b6c514d243272d3fc598a4ba56ebe3e)
set(LUA_LUASOCKET_HASH 72413e8fb6d26d5c2c6e1839072b1b21)
set(LUA_RESTY_DNS_CACHE_VERSION 32d9d461465edbec1cc798c18447c0ac7ee6e528)
set(LUA_RESTY_DNS_CACHE_HASH 3a5414110c6ad4331fe82873e19bd1e8)
set(LUA_RESTY_LOGGER_SOCKET_VERSION 15cc1c256e55b8e68ec9b220b6883c227a763d4e)
set(LUA_RESTY_LOGGER_SOCKET_HASH efe14697a8c4be612c011f54fce06191)
set(LUA_RESTY_SHCACHE_VERSION fb2e275c2cdca08eaa34a7b73375e41ac3eff200)
set(LUA_RESTY_SHCACHE_HASH 5d3cbcf8fbad1954cdcb3826afa41afe)
set(OPM_ICU_DATE_VERSION 857990ba72cf48f7ae20dfb861a783231b5a2e79)
set(OPM_ICU_DATE_HASH 580f4a650782556266cc341630d39f63)
set(OPM_LIBCIDR_VERSION 0.1.3)
set(OPM_LIBCIDR_HASH 9d995b83a7d857fcdec949725711b784)
set(OPM_RESTY_HTTP_VERSION 0.11)
set(OPM_RESTY_HTTP_HASH ad47a9d5ae64047e1f548a287b6efe11)
set(OPM_RESTY_MAIL_VERSION 1.0.0)
set(OPM_RESTY_MAIL_HASH 2b4457a32031b48417a3d7b29fbe1222)
set(OPM_RESTY_NETTLE_VERSION 0.105)
set(OPM_RESTY_NETTLE_HASH bdd23c7ee60bb135235039c1289f0138)
set(OPM_RESTY_SESSION_VERSION 2.19)
set(OPM_RESTY_SESSION_HASH 3dd80b9f503db61e7c9379d8c59107e8)
set(OPM_RESTY_VALIDATION_VERSION 2.7)
set(OPM_RESTY_VALIDATION_HASH 09c97a414981f943add1356fd90d69b5)

# LuaRock app dependencies
luarocks_install(argparse ${LUAROCK_ARGPARSE_VERSION} ${LUAROCK_ARGPARSE_HASH})
luarocks_install(bcrypt ${LUAROCK_BCRYPT_VERSION} ${LUAROCK_BCRYPT_HASH})
luarocks_install(inspect ${LUAROCK_INSPECT_VERSION} ${LUAROCK_INSPECT_HASH})
luarocks_install(lua-cmsgpack ${LUAROCK_CMSGPACK_VERSION} ${LUAROCK_CMSGPACK_HASH})
luarocks_install(lua-iconv ${LUAROCK_ICONV_VERSION} ${LUAROCK_ICONV_HASH})
luarocks_install(lua-resty-uuid ${LUAROCK_RESTY_UUID_VERSION} ${LUAROCK_RESTY_UUID_HASH})
luarocks_install(lualdap ${LUAROCK_LUALDAP_VERSION} ${LUAROCK_LUALDAP_HASH})
luarocks_install(luaposix ${LUAROCK_LUAPOSIX_VERSION} ${LUAROCK_LUAPOSIX_HASH})
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
  EXCLUDE_FROM_ALL 1
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
  lua_resty_dns_cache
  EXCLUDE_FROM_ALL 1
  DEPENDS luarocks
  URL https://github.com/hamishforbes/lua-resty-dns-cache/archive/${LUA_RESTY_DNS_CACHE_VERSION}.tar.gz
  URL_HASH MD5=${LUA_RESTY_DNS_CACHE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/lib/resty/dns/cache.lua ${VENDOR_LUA_DIR}/resty/dns/cache.lua
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
  lua_resty_dns_cache
  lua_resty_logger_socket
  lua_resty_shcache
  luarock_argparse
  luarock_bcrypt
  luarock_inspect
  luarock_lapis
  luarock_lua-cmsgpack
  luarock_lua-iconv
  luarock_lua-resty-uuid
  luarock_lualdap
  luarock_luaposix
  luarock_lustache
  luarock_lyaml
  luarock_penlight
  opm_lua-icu-date
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
