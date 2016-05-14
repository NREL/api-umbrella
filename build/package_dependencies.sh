#!/bin/bash

if [ -f /etc/redhat-release ]; then
  core_package_dependencies=(
    # General
    bash
    glibc
    libffi
    libyaml
    ncurses-libs
    openssl
    pcre
    zlib

    # lua-resty-uuid requires "libuuid.so", so we have to instal the -devel
    # package (libuuid provides "libuuid.so.1").
    libuuid-devel

    # TrafficServer
    libxml2
    tcl

    # ElasticSearch
    java-1.8.0-openjdk-headless
    # For getopt, should no longer be necessary in ElasticSearch 2:
    # https://github.com/elastic/elasticsearch/pull/12165
    util-linux-ng
    which

    # init.d script helpers
    initscripts

    # For pkill/pgrep used for legacy status/stop commands.
    procps
  )
  hadoop_analytics_package_dependencies=(
    java-1.8.0-openjdk-headless
  )
  core_build_dependencies=(
    autoconf
    automake
    bzip2
    cmake
    curl
    gcc
    gcc-c++
    git
    libffi-devel
    libcurl-devel
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
    rpm-build
    rsync
    tar
    tcl-devel
    unzip
    xz
  )
  hadoop_analytics_build_dependencies=(
    java-1.8.0-openjdk-devel
  )
elif [ -f /etc/debian_version ]; then
  core_package_dependencies=(
    # General
    bash
    libc6
    libyaml-0-2
    libncurses5
    openssl
    libpcre3
    zlib1g

    # lua-resty-uuid requires "libuuid.so", so we have to instal the -dev
    # package (libuuid1 provides "libuuid.so.1").
    uuid-dev

    # TrafficServer
    libxml2
    tcl

    # ElasticSearch
    openjdk-7-jre-headless

    # init.d script helpers
    sysvinit-utils
    lsb-base

    # For pkill/pgrep used for legacy status/stop commands.
    procps
  )
  hadoop_analytics_package_dependencies=(
    openjdk-7-jre-headless
  )
  core_build_dependencies=(
    autoconf
    automake
    bzip2
    cmake
    curl
    gcc
    g++
    git
    libffi-dev
    uuid-dev
    libcurl4-openssl-dev
    libtool
    libxml2-dev
    libyaml-dev
    lsb-release
    make
    libncurses5-dev
    openssl
    libssl-dev
    patch
    libpcre3-dev
    rsync
    tar
    tcl-dev
    unzip
    xz-utils
  )
  hadoop_analytics_build_dependencies=(
    openjdk-7-jdk-headless
  )

  if lsb_release --codename --short | grep wheezy; then
    core_package_dependencies+=("libffi5")
  else
    core_package_dependencies+=("libffi6")
  fi
else
  echo "Unknown build system"
  exit 1
fi

# shellcheck disable=SC2034
all_dependencies=(
  "${core_package_dependencies[*]}"
  "${hadoop_analytics_package_dependencies[*]}"
  "${core_build_dependencies[*]}"
  "${hadoop_analytics_build_dependencies[*]}"
)
