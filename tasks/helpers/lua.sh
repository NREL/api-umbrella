#!/usr/bin/env bash

set +x

LUA_PREFIX="$STAGE_EMBEDDED_DIR"
LUAROCKS_CMD=(
  env
  "LUA_PATH=$LUA_PREFIX/openresty/luajit/share/lua/5.1/?.lua;$LUA_PREFIX/openresty/luajit/share/lua/5.1/?/init.lua;;"
  "LUAROCKS_SYSCONFDIR=$LUA_PREFIX/openresty/luajit/etc/luarocks"
  "PATH=$STAGE_EMBEDDED_PATH"
  "LD_LIBRARY_PATH=$STAGE_EMBEDDED_DIR/openresty/luajit/lib:$STAGE_EMBEDDED_DIR/lib"
  "$LUA_PREFIX/bin/luarocks"
)

_luarocks_install() {
  tree_dir="$1"
  package="$2"
  version="$3"
  shift; shift; shift;
  extra_args=("$@")

  set -x
  "${LUAROCKS_CMD[@]}" --tree="$tree_dir" install "$package" "$version" "${extra_args[@]}"
  find "$tree_dir/lib" -name "*.so" -exec chrpath -d {} \;
}

luarocks_install() {
  set +x
  _luarocks_install "$APP_VENDOR_LUA_DIR" "$@"
}

test_luarocks_install() {
  set +x
  _luarocks_install "$TEST_VENDOR_LUA_DIR" "$@"
}

set -x
