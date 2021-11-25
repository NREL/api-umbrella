#!/usr/bin/env bash

set -e -u

source_dir="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"

# shellcheck source=tasks/helpers/detect_os_release.sh
source "$source_dir/tasks/helpers/detect_os_release.sh"
detect_os_release

if [[ "$ID_NORMALIZED" == "rhel" ]]; then
  core_runtime_dependencies=(
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
    pcre2
    postgresql
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

    # For prefixed console output (gnu version for strftime support).
    gawk

    # lua-resty-nettle
    nettle-devel

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
    pcre2-devel
    pkgconfig
    python
    readline-devel
    rpm-build
    rsync
    tar
    unzip
    xz

    # For OpenResty's "opm" CLI.
    perl-Digest-MD5

    # lualdap
    openldap-devel

    # libbson
    cmake

    # For tests and building static site.
    ruby-devel
    rubygem-bundler
  )
  test_runtime_dependencies=(
    unbound
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

    # For checking for file descriptor leaks during the tests.
    lsof

    # Fonts for Capybara screenshots.
    urw-fonts

    # For pkill/pgrep used for process tests.
    procps-ng

    # For running lsof tests in Docker as root
    sudo

    # Postgres Ruby client for tests
    libpq-devel

    # For nokogiri dependency
    libxml2-devel
    libxslt-devel
  )

  if [[ "$VERSION_ID" == "7" ]]; then
    # Install GCC 7+ for compiling TrafficServer (C++17 required).
    core_build_dependencies+=(
      centos-release-scl
      devtoolset-7
    )
  else
    core_runtime_dependencies+=(
      # lua-icu-date-ffi
      libicu-devel

      # lua-psl
      libpsl
    )

    core_build_dependencies+=(
      # lua-psl
      libpsl-devel
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

  core_runtime_dependencies=(
    # General
    bash
    libc6
    "libffi$libffi_version"
    libncurses5
    libpcre3
    libpcre2-8-0
    libuuid1
    libyaml-0-2
    logrotate
    openssl
    postgresql-client
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

    # For prefixed console output (gnu version for strftime support).
    gawk

    # lua-icu-date-ffi
    libicu-dev

    # lua-resty-nettle
    "nettle-dev"

    # lualdap
    libldap-2.4-2

    # lua-psl
    libpsl5
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
    libpcre2-dev
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
    unzip
    uuid-dev
    xz-utils
    zlib1g-dev

    # lualdap
    libldap-dev

    # libbson
    cmake

    # For tests and building static site.
    ruby-dev
    ruby-bundler

    # lua-psl
    libpsl-dev
  )
  test_runtime_dependencies=(
    unbound
  )
  test_build_dependencies=(
    # Binary and readelf tests
    file
    binutils

    # For checking for file descriptor leaks during the tests.
    lsof

    # Fonts for Capybara screenshots.
    gsfonts

    # For pkill/pgrep used for process tests.
    procps

    # For running lsof tests in Docker as root
    sudo

    # Postgres Ruby client for tests
    libpq-dev

    # For nokogiri dependency
    libxml2-dev
    libxslt-dev
  )

  # Install GCC 7+ for compiling TrafficServer (C++17 required).
  if [[ "$ID" == "debian" && "$VERSION_ID" == "9" ]]; then
    core_build_dependencies+=(
      clang-7
      libc++-7-dev
      libc++abi-7-dev
    )

    core_runtime_dependencies+=(
      libc++1-7
      libc++abi1-7
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

    core_runtime_dependencies+=(
      # ElasticSearch
      "adoptopenjdk-8-hotspot-jre"
    )
  else
    core_runtime_dependencies+=(
      # ElasticSearch
      "openjdk-8-jre-headless"
    )
  fi
else
  echo "Unknown build system"
  exit 1
fi

all_build_dependencies=(
  "${core_runtime_dependencies[@]}"
  "${core_build_dependencies[@]}"
)

# shellcheck disable=SC2034
all_dependencies=(
  "${all_build_dependencies[@]}"
  "${test_runtime_dependencies[@]}"
  "${test_build_dependencies[@]}"
)
