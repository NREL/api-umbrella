#!/usr/bin/env bash

set +x
SOURCE_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

INSTALL_PREFIX=/opt/api-umbrella
INSTALL_PREFIX_EMBEDDED="$INSTALL_PREFIX/embedded"
WORK_DIR="$SOURCE_DIR/build/work"
PACKAGE_WORK_DIR="$SOURCE_DIR/build/package/work"

# Where to stage installations during "make" phase.
STAGE_DIR="$WORK_DIR/stage"
STAGE_PREFIX_DIR="$STAGE_DIR$INSTALL_PREFIX"
STAGE_EMBEDDED_DIR="$STAGE_DIR$INSTALL_PREFIX_EMBEDDED"

# Where to install development-only dependencies.
DEV_INSTALL_PREFIX="$WORK_DIR/dev-env"
DEV_VENDOR_DIR="$DEV_INSTALL_PREFIX/vendor"

# Where to install test-only dependencies.
TEST_INSTALL_PREFIX="$WORK_DIR/test-env"
TEST_VENDOR_DIR="$TEST_INSTALL_PREFIX/vendor"
TEST_VENDOR_LUA_SHARE_DIR="$TEST_VENDOR_DIR/share/lua/5.1"
TEST_VENDOR_LUA_LIB_DIR="$TEST_VENDOR_DIR/lib/lua/5.1"

# PATH variables to use when executing other commands. Note that we use a
# hard-coded base default path (instead of $ENV{PATH}), since using $ENV{PATH}
# makes cmake think there have been PATH changes which trigger rebuilds, even
# when the path hasn't changed.
DEFAULT_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
STAGE_EMBEDDED_PATH="$STAGE_EMBEDDED_DIR/bin:$DEFAULT_PATH"
DEV_PATH="$DEV_INSTALL_PREFIX/bin:$STAGE_EMBEDDED_PATH"

# Where to install app-level vendor dependencies.
VENDOR_DIR="$WORK_DIR/vendor"
VENDOR_LUA_DIR="$VENDOR_DIR/share/lua/5.1"
LUA_PREFIX="$STAGE_EMBEDDED_DIR"
LUAROCKS_CMD=(env LUA_PATH="$LUA_PREFIX/openresty/luajit/share/lua/5.1/?.lua;$LUA_PREFIX/openresty/luajit/share/lua/5.1/?/init.lua;;" "$LUA_PREFIX/bin/luarocks")
OPM_CMD=(env LUA_PATH="$LUA_PREFIX/openresty/lualib/?.lua;$LUA_PREFIX/openresty/lualib/?/init.lua;;" PATH="$STAGE_EMBEDDED_PATH" LD_LIBRARY_PATH="$STAGE_EMBEDDED_DIR/openresty/luajit/lib:$STAGE_EMBEDDED_DIR/lib" opm)
set -x

task_working_dir() {
  set +x
  task_path=${0#*tasks/}
  dir="$WORK_DIR/tasks/$task_path"
  set -x
  mkdir -p "$dir"
  cd "$dir" || exit 1

  find "$dir" -mindepth 1 -maxdepth 1 -not -name "downloads" -exec rm -rf {} \;
}

download() {
  set +x
  url=$1
  hash_algorithm=$2
  expected_hash=$3

  filename=$(basename "$url")
  downloads_dir="$(pwd)/downloads"
  download_path="$downloads_dir/$filename"
  mkdir -p "$downloads_dir"

  if [ ! -f "$download_path" ]; then
    set -x
    curl --location --retry 3 --fail --output "$download_path" "$url"
    set +x
  fi

  actual_hash=$(openssl dgst -"$hash_algorithm" "$download_path" | awk '{print $2}')

  if [ "$expected_hash" != "$actual_hash" ]; then
    echo "Checksum for $download_path did not match"
    echo "  Expected hash: $expected_hash"
    echo "    Actual hash: $actual_hash"
    exit 1
  fi

  set -x
}

extract_download() {
  tar -xf "downloads/$1"
}

_luarocks_install() {
  tree_dir="$1"
  package="$2"
  version="$3"

  "${LUAROCKS_CMD[@]}" --tree="$tree_dir" install "$package" "$version"
  find "$tree_dir/lib/lua" -name "*.so" -exec chrpath -d {} \;
}

luarocks_install() {
  _luarocks_install "$VENDOR_DIR" "$@"
}

test_luarocks_install() {
  _luarocks_install "$TEST_VENDOR_DIR" "$@"
}

_opm_install() {
  tree_dir="$1"
  package="$2"
  account="$3"
  version="$4"

  mkdir -p "$tree_dir"
  (cd "$tree_dir" && "${OPM_CMD[@]}" --cwd get "$account/$package=$version")
  find "$tree_dir/resty_modules" -name "*.so" -exec chrpath -d {} \;
}

opm_install() {
  _opm_install "$VENDOR_DIR" "$@"
}

test_opm_install() {
  _opm_install "$TEST_VENDOR_DIR" "$@"
}
