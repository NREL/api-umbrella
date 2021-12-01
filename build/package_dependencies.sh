#!/usr/bin/env bash

set -e -u

source_dir="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"

# shellcheck source=tasks/helpers/detect_os_release.sh
source "$source_dir/tasks/helpers/detect_os_release.sh"
detect_os_release

core_package_non_build_dependencies=()

if [[ "$ID_NORMALIZED" == "rhel" ]]; then
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

    # ElasticSearch
    java-1.8.0-openjdk-headless
    which

    # rsyslog omelasticsearch
    libcurl

    # init.d script helpers
    initscripts

    # For kill used in stop/reopen-logs commands.
    util-linux

    # For pstree used in reopen-logs command.
    psmisc

    # For OpenResty's "resty" CLI.
    perl
    perl-Time-HiRes

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
    unzip
    xz

    # For OpenResty's "opm" CLI.
    perl-Digest-MD5
  )
  test_package_dependencies=(
    unbound
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

    # For installing the mongo-orchestration test dependency.
    python-virtualenv

    # For checking for file descriptor leaks during the tests.
    lsof

    # Fonts for Capybara screenshots.
    urw-fonts

    # For pkill/pgrep used for process tests.
    procps-ng

    # For running lsof tests in Docker as root
    sudo
  )

  # Install GCC 7+ for compiling TrafficServer (C++17 required).
  if [[ "$VERSION_ID" == "7" ]]; then
    core_build_dependencies+=(
      centos-release-scl
      devtoolset-7
    )
  else
    core_package_dependencies+=(
      libicu-devel
    )
  fi
elif [[ "$ID_NORMALIZED" == "debian" ]]; then
  libcurl_version=4
  libffi_version=7

  if [[ "$ID" == "debian" && ( "$VERSION_ID" == "9" || "$VERSION_ID" == "10" ) ]]; then
    libffi_version=6
  elif [[ "$ID" == "ubuntu" && "$VERSION_ID" == "18.04" ]]; then
    libffi_version=6
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

    # nokogiri
    libxml2-dev
    libxslt-dev

    # For prefixed console output (gnu version for strftime support).
    gawk

    libicu-dev
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
    unzip
    uuid-dev
    xz-utils
    zlib1g-dev
  )
  test_package_dependencies=(
    unbound
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

    # For installing the mongo-orchestration test dependency.
    virtualenv

    # For checking for file descriptor leaks during the tests.
    lsof

    # Fonts for Capybara screenshots.
    gsfonts

    # For pkill/pgrep used for process tests.
    procps

    # For running lsof tests in Docker as root
    sudo
  )

  # Install GCC 7+ for compiling TrafficServer (C++17 required).
  if [[ "$ID" == "debian" && "$VERSION_ID" == "9" ]]; then
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

  # Since we're still bundling Elasticsearch v2, this depends on an older JDK
  # version not available in newer Debian releases.
  if [[ "$ID" == "debian" && ( "$VERSION_ID" == "10" || "$VERSION_ID" == "11" ) ]]; then
    apt-get update
    apt-get -y install curl gnupg2
    echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ $VERSION_CODENAME main" > /etc/apt/sources.list.d/adoptopenjdk.list
    curl -fsSL https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add -
    apt-get update

    core_package_dependencies+=(
      # ElasticSearch
      "adoptopenjdk-8-hotspot-jre"
    )
  else
    core_package_dependencies+=(
      # ElasticSearch
      "openjdk-8-jre-headless"
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
  "${test_package_dependencies[@]}"
  "${test_build_dependencies[@]}"
)

if [ "${#core_package_non_build_dependencies[@]}" != 0 ]; then
  core_package_dependencies+=(
    "${core_package_non_build_dependencies[@]}"
  )
fi
