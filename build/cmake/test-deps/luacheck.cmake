set(LUAROCK_LUACHECK_VERSION 0.22.0-1)
set(LUAROCK_LUACHECK_HASH 17608776f5d37ca898f96f4973b3be0e)

test_luarocks_install(luacheck ${LUAROCK_LUACHECK_VERSION} ${LUAROCK_LUACHECK_HASH})

add_custom_target(luacheck DEPENDS luarock_luacheck)
