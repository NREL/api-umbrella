#!/usr/bin/env bash

set -e -u

# shellcheck disable=SC1091
if [ -f /etc/os-release ]; then
  source /etc/os-release
fi

if [ -f /etc/redhat-release ]; then
  util_linux_package="util-linux-ng"
  procps_package="procps"

  if [[ "${VERSION_ID:-}" == "7" ]]; then
    util_linux_package="util-linux"
    procps_package="procps-ng"
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

    # lua-icu-date
    libicu-devel

    # lua-resty-nettle
    nettle

    # lualdap
    openldap
  )
  hadoop_analytics_package_dependencies=(
    java-1.8.0-openjdk-headless
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
    openssl
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

    # Building the static-site
    ruby
    rubygem-bundler

    # lualdap
    openldap-devel
  )
  hadoop_analytics_build_dependencies=(
    java-1.8.0-openjdk-devel
  )
  test_build_dependencies=(
    # Running tests
    ruby
    rubygem-bundler

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
  )
elif [ -f /etc/debian_version ]; then
  libffi_version=6
  libnettle_version=6
  libreadline_version=6
  openjdk_version=7

  if [[ "$ID" == "debian" && "$VERSION_ID" == "7" ]]; then
    libffi_version=5
  fi
  if [[ "$ID" == "debian" && "$VERSION_ID" == "7" ]] || [[ "$ID" == "debian" && "$VERSION_ID" == "8" ]] || [[ "$ID" == "ubuntu" && "$VERSION_ID" == "14.04" ]]; then
    libnettle_version=4
  fi
  if [[ "$ID" == "debian" && "$VERSION_ID" == "9" ]] || [[ "$ID" == "ubuntu" && "$VERSION_ID" == "16.04" ]]; then
    openjdk_version=8
  fi
  if [[ "$ID" == "debian" && "$VERSION_ID" == "9" ]]; then
    libreadline_version=7
  fi

  core_package_dependencies=(
    # General
    bash
    libc6
    "libffi$libffi_version"
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
    libcurl3

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

    # lua-icu-date
    libicu-dev

    # lua-resty-nettle
    "libnettle$libnettle_version"

    # lualdap
    libldap-2.4-2
  )
  hadoop_analytics_package_dependencies=(
    "openjdk-$openjdk_version-jre-headless"
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
    libxml2-dev
    libyaml-dev
    lsb-release
    make
    openssl
    patch
    pkg-config
    python
    rsync
    tar
    tcl-dev
    unzip
    uuid-dev
    xz-utils

    # Building the static-site
    ruby
    bundler

    # lualdap
    libldap-dev
  )
  hadoop_analytics_build_dependencies=(
    "openjdk-$openjdk_version-jdk"
  )
  test_build_dependencies=(
    # Running tests
    ruby
    bundler

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
  )

  if [[ "$ID" == "debian" && "$VERSION_ID" == "8" ]] || [[ "$ID" == "debian" && "$VERSION_ID" == "9" ]] || [[ "$ID" == "ubuntu" && "$VERSION_ID" == "16.04" ]]; then
    core_build_dependencies+=("libtool-bin")
  fi
else
  echo "Unknown build system"
  exit 1
fi

all_build_dependencies=(
  "${core_package_dependencies[@]}"
  "${hadoop_analytics_package_dependencies[@]}"
  "${core_build_dependencies[@]}"
  "${hadoop_analytics_build_dependencies[@]}"
)

# shellcheck disable=SC2034
all_dependencies=(
  "${all_build_dependencies[@]}"
  "${test_build_dependencies[@]}"
)
