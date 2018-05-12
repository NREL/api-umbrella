# rsyslog: Log buffering and processing

set(LIBESTR_VERSION 0.1.10)
set(LIBESTR_HASH bd655e126e750edd18544b88eb1568d200a424a0c23f665eb14bbece07ac703c)
set(LIBFASTJSON_VERSION 0.99.8)
set(LIBFASTJSON_HASH 730713ad1d851def7ac8898f751bbfdd)
set(LIBLOGGING_VERSION 1.0.6)
set(LIBLOGGING_HASH 338c6174e5c8652eaa34f956be3451f7491a4416ab489aef63151f802b00bf93)
set(RSYSLOG_VERSION 8.34.0)
set(RSYSLOG_HASH 18330a9764c55d2501b847aad267292bd96c2b12fa5c3b92909bd8d4563c80a9)

find_package(CURL REQUIRED)
require_program(autoconf)
require_program(automake)
require_program(libtool)
pkg_check_modules(LIBUUID REQUIRED uuid)

# Build libestr dependency for rsyslog, since Ubuntu 12.04's package is too old
# and CentOS 6's package has some pkg-config issues, so it's not picked up
# (https://bugzilla.redhat.com/show_bug.cgi?id=1152899).
ExternalProject_Add(
  libestr
  EXCLUDE_FROM_ALL 1
  URL http://libestr.adiscon.com/files/download/libestr-${LIBESTR_VERSION}.tar.gz
  URL_HASH SHA256=${LIBESTR_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  libfastjson
  EXCLUDE_FROM_ALL 1
  URL https://github.com/rsyslog/libfastjson/archive/v${LIBFASTJSON_VERSION}.tar.gz
  URL_HASH MD5=${LIBFASTJSON_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND sh autogen.sh
    COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

list(APPEND LIBLOGGING_CONFIGURE_CMD env)
list(APPEND LIBLOGGING_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND LIBLOGGING_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND LIBLOGGING_CONFIGURE_CMD --disable-man-pages)
ExternalProject_Add(
  liblogging
  EXCLUDE_FROM_ALL 1
  URL http://download.rsyslog.com/liblogging/liblogging-${LIBLOGGING_VERSION}.tar.gz
  URL_HASH SHA256=${LIBLOGGING_HASH}
  BUILD_IN_SOURCE 1
  # Run autoreconf to fix issues with the bundled configure file being built
  # with specific versions of autoreconf and libtool that might be newer than
  # the default OS packages.
  CONFIGURE_COMMAND autoreconf --force --install -v
    COMMAND ${LIBLOGGING_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND chrpath -d ${STAGE_EMBEDDED_DIR}/bin/stdlogctl
)

list(APPEND RSYSLOG_DEPENDS libestr)
list(APPEND RSYSLOG_DEPENDS libfastjson)
list(APPEND RSYSLOG_DEPENDS liblogging)

list(APPEND RSYSLOG_CONFIGURE_CMD env)
list(APPEND RSYSLOG_CONFIGURE_CMD LIBESTR_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBESTR_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lestr")
list(APPEND RSYSLOG_CONFIGURE_CMD LIBFASTJSON_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include/libfastjson)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBFASTJSON_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lfastjson")
list(APPEND RSYSLOG_CONFIGURE_CMD LIBLOGGING_STDLOG_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBLOGGING_STDLOG_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -llogging-stdlog")
list(APPEND RSYSLOG_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND RSYSLOG_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-liblogging-stdlog)
list(APPEND RSYSLOG_CONFIGURE_CMD --disable-libgcrypt)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-imptcp)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-impstats)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-mmjsonparse)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-mmutf8fix)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-elasticsearch)

ExternalProject_Add(
  rsyslog
  EXCLUDE_FROM_ALL 1
  DEPENDS ${RSYSLOG_DEPENDS}
  URL http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-${RSYSLOG_VERSION}.tar.gz
  URL_HASH SHA256=${RSYSLOG_HASH}
  CONFIGURE_COMMAND rm -rf <BINARY_DIR> && mkdir -p <BINARY_DIR> # Clean across version upgrades
    COMMAND ${RSYSLOG_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND chrpath -d ${STAGE_EMBEDDED_DIR}/sbin/rsyslogd
    COMMAND find ${STAGE_EMBEDDED_DIR}/lib/rsyslog/ -name *.so -exec chrpath -d {} $<SEMICOLON>
)
