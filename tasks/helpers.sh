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
APP_CORE_DIR="$STAGE_EMBEDDED_DIR/apps/core"
APP_CORE_RELEASE_DIR="$APP_CORE_DIR/releases/0"
APP_CORE_VENDOR_DIR="$APP_CORE_DIR/shared/vendor"
APP_CORE_VENDOR_BUNDLE_DIR="$APP_CORE_VENDOR_DIR/bundle"
APP_CORE_VENDOR_LUA_DIR="$APP_CORE_VENDOR_DIR/lua"
APP_CORE_VENDOR_LUA_SHARE_DIR="$APP_CORE_VENDOR_LUA_DIR/share/lua/5.1"
LUA_PREFIX="$STAGE_EMBEDDED_DIR"
LUAROCKS_CMD=(env "LUA_PATH=$LUA_PREFIX/openresty/luajit/share/lua/5.1/?.lua;$LUA_PREFIX/openresty/luajit/share/lua/5.1/?/init.lua;;" "$LUA_PREFIX/bin/luarocks")
OPM_CMD=(env "LUA_PATH=$LUA_PREFIX/openresty/lualib/?.lua;$LUA_PREFIX/openresty/lualib/?/init.lua;;" "PATH=$STAGE_EMBEDDED_PATH" "LD_LIBRARY_PATH=$STAGE_EMBEDDED_DIR/openresty/luajit/lib:$STAGE_EMBEDDED_DIR/lib" opm)

# Determine the sub-path for the currently executing task. This can be used for
# generating unique directories for the current task.
#
# For example, ./tasks/deps/openresty's subpath would be "deps/openresty"
TASK_SUBPATH="${BASH_SOURCE[1]#*tasks/}"

# Creating a working directory for the currently running task under
# ./build/work/tasks/*
#
# For example, ./tasks/deps/openresty's working directory would be
# ./build/work/tasks/deps/openresty
task_working_dir() {
  set +x
  dir="$WORK_DIR/tasks/$TASK_SUBPATH"
  set -x

  # Make the directory and cd into it.
  mkdir -p "$dir"
  cd "$dir" || exit 1

  # Cleanup any files not in the special "_persist" directory before running
  # the rest of the task. This ensures clean builds if a task is being executed
  # (since we assume the task script is only being executed if the checksum has
  # changed). The persist directory is used for some items, like downloads,
  # just to speed-up development rebuilds a bit.
  find "$dir" -mindepth 1 -maxdepth 1 -not -name "_persist" -print -exec rm -rf {} \;
}

# Generate a stamp file indicating a task has successfully run. This should be
# the last line in each task file.
#
# In conjunction with go-task's checksum and dependency functionality, these
# stamp files ensure that each task has an output file that can be setup as a
# dependency for other tasks. Since each task will only run if necessary (due
# to go-tasks's checksumming), these stamp files should change on every
# successful run so that any dependencies of the current task also get
# triggered (in a cascading fashion).
stamp() {
  set +x
  stamp_path="$WORK_DIR/stamp/$TASK_SUBPATH"
  stamp_dir=$(dirname "$stamp_path")

  # Remove the previous stamp. Also try removing the parent stamp_dir if it's
  # actually a file (to handle situations where the task is shifted into or out
  # of a subdirectory).
  rm -rf "$stamp_path"
  if [ -f "$stamp_dir" ]; then
    rm -f "$stamp_dir"
  fi
  mkdir -p "$stamp_dir"

  # Generate random content within the stamp file to ensure it's checksum will
  # change on each successful run.
  echo "Stamp: $stamp_path"
  date > "$stamp_path"
  openssl rand -hex 64 >> "$stamp_path"

  set -x
}

download() {
  set +x
  url=$1
  hash_algorithm=$2
  expected_hash=$3

  # Download the file.
  filename=$(basename "$url")
  downloads_dir="$(pwd)/_persist/downloads"
  download_path="$downloads_dir/$filename"
  mkdir -p "$downloads_dir"
  if [ ! -f "$download_path" ]; then
    set -x
    curl --location --retry 3 --fail --output "$download_path" "$url"
    set +x
  fi

  # Verify the checksum of the downloaded file.
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
  tar -xf "_persist/downloads/$1"
}

_luarocks_install() {
  tree_dir="$1"
  package="$2"
  version="$3"

  set -x
  "${LUAROCKS_CMD[@]}" --tree="$tree_dir" install "$package" "$version"
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
