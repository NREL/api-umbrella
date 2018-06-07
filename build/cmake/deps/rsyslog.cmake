# rsyslog: Log buffering and processing

set(LIBESTR_VERSION 0.1.10)
set(LIBESTR_HASH bd655e126e750edd18544b88eb1568d200a424a0c23f665eb14bbece07ac703c)
set(LIBFASTJSON_VERSION 0.99.8)
set(LIBFASTJSON_HASH 730713ad1d851def7ac8898f751bbfdd)
set(RSYSLOG_VERSION 8.35.0)
set(RSYSLOG_HASH d216a7f7c88341d5964657e61a33193c13d884c988822fced9fce3ab0b1f1082)

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

list(APPEND RSYSLOG_DEPENDS libestr)
list(APPEND RSYSLOG_DEPENDS libfastjson)

list(APPEND RSYSLOG_CONFIGURE_CMD env)
list(APPEND RSYSLOG_CONFIGURE_CMD LIBESTR_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBESTR_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lestr")
list(APPEND RSYSLOG_CONFIGURE_CMD LIBFASTJSON_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include/libfastjson)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBFASTJSON_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lfastjson")
list(APPEND RSYSLOG_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND RSYSLOG_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND RSYSLOG_CONFIGURE_CMD --disable-liblogging-stdlog)
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
