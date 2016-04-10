set(PACKAGE_VERSION_ITERATION 1)

file(STRINGS ${CMAKE_SOURCE_DIR}/src/api-umbrella/version.txt VERSION_STRING)
string(REGEX MATCH "^([^-]+)" PACKAGE_VERSION ${VERSION_STRING})
string(REGEX MATCH "-(.+)$" VERSION_PRE ${VERSION_STRING})
if(VERSION_PRE)
  string(REGEX REPLACE "^-" "" VERSION_PRE ${VERSION_PRE})
  set(PACKAGE_VERSION_ITERATION 0.${PACKAGE_VERSION_ITERATION}.${VERSION_PRE})
endif()

if(EXISTS "/etc/redhat-release")
  set(PACKAGE_TYPE rpm)
  set(
    CORE_PACKAGE_DEPENDENCIES

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
  set(
    HADOOP_ANALYTICS_PACKAGE_DEPENDENCIES
    java-1.8.0-openjdk-headless
  )
  set(
    BUILD_DEPENDENCIES
    bzip2
    curl
    gcc
    gcc-c++
    git
    libffi-devel
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

  execute_process(
    COMMAND rpm --query centos-release
    OUTPUT_VARIABLE RPM_DIST
  )
  STRING(REGEX MATCH "el[0-9]+" RPM_DIST ${RPM_DIST})

  if(RPM_DIST EQUAL el6)
    if(NOT EXISTS /etc/yum.repos.d/wandisco-git.repo)
      list(INSERT BUILD_DEPENDENCIES 0 http://opensource.wandisco.com/centos/6/git/x86_64/wandisco-git-release-6-1.noarch.rpm)
    endif()
  endif()

  add_custom_target(
    package_install_system_dependencies
    COMMAND yum -y install ${CORE_PACKAGE_DEPENDENCIES} ${HADOOP_ANALYTICS_PACKAGE_DEPENDENCIES} ${BUILD_DEPENDENCIES}
  )
elseif(EXISTS "/etc/debian_version")
  set(PACKAGE_TYPE deb)

  set(
    CORE_PACKAGE_DEPENDENCIES

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
  set(
    HADOOP_ANALYTICS_PACKAGE_DEPENDENCIES
    openjdk-7-jre-headless
  )
  set(
    BUILD_DEPENDENCIES
    bzip2
    cmake
    curl
    gcc
    g++
    git
    libffi-dev
    uuid-dev
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

  execute_process(
    COMMAND lsb_release --codename --short
    OUTPUT_VARIABLE RELEASE_NAME
  )

  if(RELEASE_NAME STREQUAL wheezy)
    list(APPEND CORE_PACKAGE_DEPENDENCIES libffi5)
  else()
    list(APPEND CORE_PACKAGE_DEPENDENCIES libffi6)
  endif()

  add_custom_target(
    package_install_system_dependencies
    COMMAND apt-get update
    COMMAND apt-get -y install ${CORE_PACKAGE_DEPENDENCIES} ${HADOOP_ANALYTICS_PACKAGE_DEPENDENCIES} ${BUILD_DEPENDENCIES}
  )

  set(PACKAGE_VERSION_ITERATION "${PACKAGE_VERSION_ITERATION}~${RELEASE_NAME}")
else()
  message(FATAL_ERROR "Unknown build system")
endif()

add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
  DEPENDS ${CMAKE_SOURCE_DIR}/build/package/Gemfile ${CMAKE_SOURCE_DIR}/build/package/Gemfile.lock
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/build/package
  COMMAND bundle install --clean --path=${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
    COMMAND touch -c ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
)

set(FPM_ARGS)
list(APPEND FPM_ARGS -t ${PACKAGE_TYPE})
list(APPEND FPM_ARGS -s dir)
list(APPEND FPM_ARGS -C ${WORK_DIR}/package-dest-core)
list(APPEND FPM_ARGS --verbose)
list(APPEND FPM_ARGS --name api-umbrella)
list(APPEND FPM_ARGS --license MIT)
list(APPEND FPM_ARGS --url https://apiumbrella.io)
list(APPEND FPM_ARGS --version ${PACKAGE_VERSION})
list(APPEND FPM_ARGS --iteration ${PACKAGE_VERSION_ITERATION})
list(APPEND FPM_ARGS --config-files etc/api-umbrella/api-umbrella.yml)
list(APPEND FPM_ARGS --after-install ${CMAKE_SOURCE_DIR}/build/package/scripts/after-install)
list(APPEND FPM_ARGS --before-remove ${CMAKE_SOURCE_DIR}/build/package/scripts/before-remove)
list(APPEND FPM_ARGS --after-remove ${CMAKE_SOURCE_DIR}/build/package/scripts/after-remove)
list(APPEND FPM_ARGS --directories /etc/api-umbrella)
list(APPEND FPM_ARGS --directories /opt/api-umbrella)
foreach(DEP IN LISTS CORE_PACKAGE_DEPENDENCIES)
  list(APPEND FPM_ARGS --depends ${DEP})
endforeach()
if(PACKAGE_TYPE STREQUAL rpm)
  list(APPEND FPM_ARGS --rpm-dist ${RPM_DIST})
  list(APPEND FPM_ARGS --rpm-compression xz)
elseif(PACKAGE_TYPE STREQUAL deb)
  list(APPEND FPM_ARGS --deb-compression xz)
  list(APPEND FPM_ARGS --deb-no-default-config-files)
endif()

add_custom_target(
  package-core
  DEPENDS ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
  COMMAND make install-core DESTDIR=${WORK_DIR}/package-dest-core
  COMMAND mkdir -p ${WORK_DIR}/packages
  COMMAND cd ${WORK_DIR}/packages && env BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile XZ_OPT=-9 bundle exec fpm ${FPM_ARGS} .
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
)

set(FPM_ARGS)
list(APPEND FPM_ARGS -t ${PACKAGE_TYPE})
list(APPEND FPM_ARGS -s dir)
list(APPEND FPM_ARGS -C ${WORK_DIR}/package-dest-hadoop-analytics)
list(APPEND FPM_ARGS --verbose)
list(APPEND FPM_ARGS --name api-umbrella-hadoop-analytics)
list(APPEND FPM_ARGS --license MIT)
list(APPEND FPM_ARGS --url https://apiumbrella.io)
list(APPEND FPM_ARGS --version ${VERSION})
list(APPEND FPM_ARGS --iteration ${ITERATION})
list(APPEND FPM_ARGS --directories /opt/api-umbrella)
list(APPEND FPM_ARGS --depends api-umbrella)
foreach(DEP IN LISTS HADOOP_ANALYTICS_PACKAGE_DEPENDENCIES)
  list(APPEND FPM_ARGS --depends ${DEP})
endforeach()
if(PACKAGE_TYPE STREQUAL rpm)
  list(APPEND FPM_ARGS --rpm-dist ${RPM_DIST})
  list(APPEND FPM_ARGS --rpm-compression xz)
elseif(PACKAGE_TYPE STREQUAL deb)
  list(APPEND FPM_ARGS --deb-compression xz)
  list(APPEND FPM_ARGS --deb-no-default-config-files)
endif()

add_custom_target(
  package-hadoop-analytics
  DEPENDS ${CMAKE_SOURCE_DIR}/build/package/vendor/bundle
  COMMAND rm -rf ${WORK_DIR}/package-dest-hadoop-analytics
  COMMAND make install-hadoop-analytics DESTDIR=${WORK_DIR}/package-dest-hadoop-analytics
  COMMAND mkdir -p ${WORK_DIR}/packages
  COMMAND cd ${WORK_DIR}/packages && env BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile XZ_OPT=-9 bundle exec fpm ${FPM_ARGS} .
  COMMAND rm -rf ${WORK_DIR}/package-dest-hadoop-analytics
)

add_custom_target(
  package
  COMMAND ${CMAKE_BUILD_TOOL} package-core
  COMMAND ${CMAKE_BUILD_TOOL} package-hadoop-analytics
)
