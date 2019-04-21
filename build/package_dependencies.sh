#!/usr/bin/env bash

set -e -u

if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  source /etc/os-release
fi

core_package_non_build_dependencies=()

if [ -f /etc/redhat-release ]; then
  if [[ "${VERSION_ID:-}" == "" ]]; then
    VERSION_ID=$(grep -oP '(?<= )[0-9]+(?=\.)' /etc/redhat-release)
  fi

  util_linux_package="util-linux"
  procps_package="procps-ng"

  if [[ "$VERSION_ID" == "6" ]]; then
    util_linux_package="util-linux-ng"
    procps_package="procps"
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

    # Postgresql
    readline
    tzdata
    glibc-common

    # lua-icu-date
    libicu-devel

    # For prefixed console output (gnu version for strftime support).
    gawk

    # lua-resty-nettle
    nettle

    # lualdap
    openldap
  )
  core_build_dependencies=(
    autoconf
    automake
    bzip2
    chrpath
    gcc
    gcc-c++
    gettext
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
    readline-devel
    rpm-build
    rsync
    tar
    tcl-devel
    unzip
    xz

    # For "unbuffer" command for Taskfile.
    expect

    # lualdap
    openldap-devel

    # libbson
    cmake
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

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

    # nokogiri test dependency
    libxml2-devel
    libxslt-devel
  )

  # Install GCC 7+ for compiling TrafficServer (C++17 required).
  if [[ "$VERSION_ID" == "6" || "$VERSION_ID" == "7" ]]; then
    core_build_dependencies+=(
      centos-release-scl
      devtoolset-7
    )
  fi
elif [ -f /etc/debian_version ]; then
  libcurl_version=3
  libnettle_version=6
  libreadline_version=7
  openjdk_version=8

  if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "18.04" ]]; then
    libcurl_version=4
  fi

  if [[ "$ID" == "debian" && "$VERSION_ID" == "8" ]]; then
    libnettle_version=4
  fi

  if [[ "$ID" == "debian" && "$VERSION_ID" == "8" ]] || [[ "$ID" == "ubuntu" && "$VERSION_ID" == "16.04" ]]; then
    libreadline_version=6
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

    # Postgresql
    "libreadline$libreadline_version"
    tzdata
    locales-all

    # lua-icu-date
    libicu-dev

    # For prefixed console output (gnu version for strftime support).
    gawk

    # lua-resty-nettle
    "libnettle$libnettle_version"

    # lualdap
    libldap-2.4-2
  )
  core_build_dependencies=(
    autoconf
    automake
    bzip2
    chrpath
    g++
    gcc
    gettext
    git
    libcurl4-openssl-dev
    libffi-dev
    libjansson-dev
    libncurses5-dev
    libpcre3-dev
    libreadline-dev
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

    # lualdap
    libldap-dev

    # libbson
    cmake
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

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

    # nokogiri test dependency
    libxml2-dev
    libxslt-dev
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

core_package_dependencies+=(
  "${core_package_non_build_dependencies[@]}"
)
