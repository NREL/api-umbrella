#!/usr/bin/env bash
# shellcheck disable=SC2034

set +x

SOURCE_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

if [ -z "${BUILD_DIR:-}" ]; then
  BUILD_DIR="$SOURCE_DIR"
fi

INSTALL_PREFIX=/opt/api-umbrella
INSTALL_PREFIX_EMBEDDED="$INSTALL_PREFIX/embedded"
WORK_DIR="$BUILD_DIR/build/work"
PACKAGE_WORK_DIR="$BUILD_DIR/build/package/work"

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

# PATH variables to use when executing other commands.
DEFAULT_PATH="$PATH"
STAGE_EMBEDDED_PATH="$STAGE_EMBEDDED_DIR/bin:$DEFAULT_PATH"
DEV_PATH="$DEV_INSTALL_PREFIX/bin:$STAGE_EMBEDDED_PATH"

# Where to install app-level vendor dependencies.
APP_DIR="$STAGE_EMBEDDED_DIR/app"
APP_VENDOR_DIR="$APP_DIR/vendor"
APP_VENDOR_LUA_DIR="$APP_VENDOR_DIR/lua"
APP_VENDOR_LUA_SHARE_DIR="$APP_VENDOR_LUA_DIR/share/lua/5.1"

# Determine the sub-path for the currently executing task. This can be used for
# generating unique directories for the current task.
#
# For example, ./tasks/deps/openresty's subpath would be "deps/openresty"
TASK_SUBPATH="${BASH_SOURCE[1]#*tasks/}"

# Number of processors for parallel builds.
NPROC=$(grep -c ^processor /proc/cpuinfo)

# Limit parallel builds, since we've seen some odd build failures for very high
# numbers (Trafficserver consistently fails in the CI environment with 32
# processors).
if [[ "$NPROC" -gt 4 ]]; then
  NPROC=4
fi

if [ -z "${TARGETARCH:-}" ]; then
  TARGETARCH=$(uname -m)

  # Normalize architectures based on how Docker and Go represents these:
  # https://stackoverflow.com/a/70889505
  if [ "$TARGETARCH" == "aarch64" ]; then
    TARGETARCH="arm64"
  elif [ "$TARGETARCH" == "x86_64" ]; then
    TARGETARCH="amd64"
  fi
fi

# Cleanup any files not in the special "_persist" directory before and after
# running tasks. This ensures clean builds if a task is being executed (since
# we assume the task script is only being executed if the checksum has
# changed), and also prevents intermediate build files from hanging around and
# taking up lots of space.
#
# The "_persist" directory is used for items that need to be shared across
# tasks, or for things like downloads, just to speed-up development rebuilds a
# bit.
clean_task_working_dir() {
  set +x
  dir="$WORK_DIR/tasks/$TASK_SUBPATH"
  set -x

  if [[ -d "$dir" && "${DEBUG_TASK_SKIP_CLEAN:-}" != "true" ]]; then
    # Go to the task parent directory, since cleaning may end up deleting
    # sub-paths where the shell is currently cd-ed into.
    cd "$dir" || exit 1

    find "$dir" -mindepth 1 -maxdepth 1 -not -name "_persist" -print -exec rm -rf {} \;
  fi
}

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

  # Clean the working directory before running the task to ensure a clean
  # build.
  clean_task_working_dir
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
  # Clean the working directory after successfully running the task to free up
  # disk space (since we don't need the intermediate build files).
  clean_task_working_dir

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
  tar -xof "_persist/downloads/$1"
}

set -x
