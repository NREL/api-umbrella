#!/usr/bin/env bash

set -e -u

# shellcheck disable=SC1091
if [ -f /etc/os-release ]; then
  source /etc/os-release
fi

if [ -f /etc/redhat-release ]; then
  util_linux_package="util-linux"
  procps_package="procps-ng"

  if [[ "${VERSION_ID:-}" == "6" ]]; then
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

    # lua-icu-date
    libicu-devel

    # nokogiri
    libxml2-devel
    libxslt-devel
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
  )
elif [ -f /etc/debian_version ]; then
  libcurl_version=3
  libtool_bin_package="libtool-bin"
  openjdk_version=8

  if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "18.04" ]]; then
    libcurl_version=4
  fi

  if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "14.04" ]]; then
    libtool_bin_package="libtool"
  fi

  if [[ "$ID" == "debian" && "$VERSION_ID" == "8" ]] || [[ "$ID" == "ubuntu" && "$VERSION_ID" == "14.04" ]]; then
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
    "$libtool_bin_package"
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
    flex
    libexpat-dev

    # Fonts for Capybara screenshots.
    gsfonts

    # For pkill/pgrep used for process tests.
    procps

    # OpenLDAP
    groff-base
  )

  if [[ "$ID" != "ubuntu" || "$VERSION_ID" != "14.04" ]]; then
    test_build_dependencies+=("virtualenv")
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
