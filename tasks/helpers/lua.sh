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
OPM_CMD=(
  env
  "LUA_PATH=$LUA_PREFIX/openresty/lualib/?.lua;$LUA_PREFIX/openresty/lualib/?/init.lua;;"
  "PATH=$STAGE_EMBEDDED_PATH"
  "LD_LIBRARY_PATH=$STAGE_EMBEDDED_DIR/openresty/luajit/lib:$STAGE_EMBEDDED_DIR/lib"
  opm
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
  _luarocks_install "$APP_CORE_VENDOR_LUA_DIR" "$@"
}

test_luarocks_install() {
  set +x
  _luarocks_install "$TEST_VENDOR_DIR" "$@"
}

_luarocks_make() {
  tree_dir="$1"
  package_dir="$2"
  rockspec_file="$3"
  shift; shift; shift;
  extra_args=("$@")

  set -x
  cd "$package_dir" || exit 1
  "${LUAROCKS_CMD[@]}" --tree="$tree_dir" make --local "$rockspec_file" "${extra_args[@]}"
  find "$tree_dir/lib" -name "*.so" -exec chrpath -d {} \;
}

luarocks_make() {
  set +x
  _luarocks_make "$APP_CORE_VENDOR_LUA_DIR" "$@"
}

_opm_install() {
  tree_dir="$1"
  package="$2"
  version="$3"

  set -x
  mkdir -p "$tree_dir"
  (cd "$tree_dir" && "${OPM_CMD[@]}" --cwd get "$package=$version")
  find "$tree_dir/resty_modules" -name "*.so" -exec chrpath -d {} \;
}

opm_install() {
  set +x
  _opm_install "$APP_CORE_VENDOR_LUA_DIR" "$@"
}

test_opm_install() {
  set +x
  _opm_install "$TEST_VENDOR_DIR" "$@"
}

set -x
