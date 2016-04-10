# Luarocks test dependencies
test_luarocks_install(luacheck ${LUAROCK_LUACHECK_VERSION})

add_custom_target(
  test-lua-deps
  DEPENDS luarock_luacheck
)
