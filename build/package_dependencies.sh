#!/usr/bin/env bash

set -e -u

source_dir="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"

# shellcheck source=tasks/helpers/detect_os_release.sh
source "$source_dir/tasks/helpers/detect_os_release.sh"
detect_os_release

core_package_non_build_dependencies=()

if [[ "$ID_NORMALIZED" == "rhel" ]]; then
  perl_digest_md5_package="perl-Digest-MD5"
  procps_package="procps-ng"
  util_linux_package="util-linux"

  if [[ "$VERSION_ID" == "6" ]]; then
    perl_digest_md5_package="perl"
    procps_package="procps"
    util_linux_package="util-linux-ng"
  fi

  core_package_dependencies=(
    # General
    bash
    glibc
    libffi
    libuuid
    libyaml
    logrotate
    ncurses-libs
    openssl
    pcre
    zlib

    # geoip-auto-updater
    coreutils
    curl
    gzip

    # TrafficServer
    libxml2
    tcl

    # ElasticSearch
    java-1.8.0-openjdk-headless
    which

    # rsyslog omelasticsearch
    libcurl

    # init.d script helpers
    initscripts

    # For kill used in stop/reopen-logs commands.
    "$util_linux_package"

    # For pstree used in reopen-logs command.
    psmisc

    # For OpenResty's "resty" CLI.
    perl
    perl-Time-HiRes

    # lua-icu-date
    libicu-devel

    # nokogiri
    libxml2-devel
    libxslt-devel

    # For prefixed console output (gnu version for strftime support).
    gawk
  )
  core_build_dependencies=(
    autoconf
    automake
    bzip2
    chrpath
    gcc
    gcc-c++
    git
    libcurl-devel
    libffi-devel
    libtool
    libuuid-devel
    libxml2-devel
    libyaml-devel
    make
    ncurses-devel
    openssl-devel
    patch
    pcre-devel
    pkgconfig
    python
    rpm-build
    rsync
    tar
    tcl-devel
    unzip
    xz

    # For OpenResty's "opm" CLI.
    "$perl_digest_md5_package"

    # For "unbuffer" command for Taskfile.
    expect
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

    # For installing the mongo-orchestration test dependency.
    python-virtualenv

    # For checking for file descriptor leaks during the tests.
    lsof

    # Unbound
    bison
    expat-devel
    flex

    # Fonts for Capybara screenshots.
    urw-fonts

    # For pkill/pgrep used for process tests.
    "$procps_package"

    # OpenLDAP
    groff

    # For running lsof tests in Docker as root
    sudo
  )

  # Install GCC 7+ for compiling TrafficServer (C++17 required).
  if [[ "$VERSION_ID" == "6" || "$VERSION_ID" == "7" ]]; then
    core_build_dependencies+=(
      centos-release-scl
      devtoolset-7
    )
  fi
elif [[ "$ID_NORMALIZED" == "debian" ]]; then
  libcurl_version=3
  openjdk_version=8

  if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "18.04" ]]; then
    libcurl_version=4
  fi

  if [[ "$ID" == "debian" && "$VERSION_ID" == "8" ]]; then
    openjdk_version=7
  fi

  core_package_dependencies=(
    # General
    bash
    libc6
    libffi6
    libncurses5
    libpcre3
    libuuid1
    libyaml-0-2
    logrotate
    openssl
    zlib1g

    # geoip-auto-updater
    coreutils
    curl
    gzip

    # TrafficServer
    libxml2
    tcl

    # ElasticSearch
    "openjdk-$openjdk_version-jre-headless"

    # rsyslog omelasticsearch
    "libcurl$libcurl_version"

    # init.d script helpers
    sysvinit-utils
    lsb-base

    # For kill used in stop/reopen-logs commands.
    procps

    # For pstree used in reopen-logs command.
    psmisc

    # For OpenResty's "resty" CLI.
    perl

    # lua-icu-date
    libicu-dev

    # nokogiri
    libxml2-dev
    libxslt-dev

    # For prefixed console output (gnu version for strftime support).
    gawk
  )
  core_build_dependencies=(
    autoconf
    automake
    bzip2
    chrpath
    g++
    gcc
    git
    libcurl4-openssl-dev
    libffi-dev
    libncurses5-dev
    libpcre3-dev
    libssl-dev
    libtool
    libtool-bin
    libxml2-dev
    libyaml-dev
    lsb-release
    make
    patch
    pkg-config
    python
    rsync
    tar
    tcl-dev
    unzip
    uuid-dev
    xz-utils

    # For "unbuffer" command for Taskfile.
    expect
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

    # For installing the mongo-orchestration test dependency.
    python-virtualenv
    virtualenv

    # For checking for file descriptor leaks during the tests.
    lsof

    # Unbound
    bison
    flex
    libexpat-dev

    # Fonts for Capybara screenshots.
    gsfonts

    # For pkill/pgrep used for process tests.
    procps

    # OpenLDAP
    groff-base

    # For running lsof tests in Docker as root
    sudo
  )

  # Install GCC 7+ for compiling TrafficServer (C++17 required).
  if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "16.04" ]]; then
    core_build_dependencies+=(
      gcc-7
      g++-7
    )
  elif [[ "$ID" == "debian" && ( "$VERSION_ID" == "8" || "$VERSION_ID" == "9" ) ]]; then
    core_build_dependencies+=(
      clang-7
      libc++-7-dev
      libc++abi-7-dev
    )

    core_package_non_build_dependencies+=(
      libc++1
      libc++abi1
    )
  fi
else
  echo "Unknown build system"
  exit 1
fi

all_build_dependencies=(
  "${core_package_dependencies[@]}"
  "${core_build_dependencies[@]}"
)

# shellcheck disable=SC2034
all_dependencies=(
  "${all_build_dependencies[@]}"
  "${test_build_dependencies[@]}"
)

if [ "${#core_package_non_build_dependencies[@]}" != 0 ]; then
  core_package_dependencies+=(
    "${core_package_non_build_dependencies[@]}"
  )
fi
