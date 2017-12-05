set(LUAROCK_LUACHECK_VERSION 0.21.2-1)
set(LUAROCK_LUACHECK_HASH 2db2625f0c0008cfa1910b2b75926231)

test_luarocks_install(luacheck ${LUAROCK_LUACHECK_VERSION} ${LUAROCK_LUACHECK_HASH})

add_custom_target(luacheck DEPENDS luarock_luacheck)
