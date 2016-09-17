# Luarocks test dependencies
test_luarocks_install(luacheck ${LUAROCK_LUACHECK_VERSION} ${LUAROCK_LUACHECK_HASH})

add_custom_target(
  test-lua-deps
  DEPENDS luarock_luacheck
)
