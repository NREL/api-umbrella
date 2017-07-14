# rsyslog: Log buffering and processing

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
  URL http://libestr.adiscon.com/files/download/libestr-${LIBESTR_VERSION}.tar.gz
  URL_HASH SHA256=${LIBESTR_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  libfastjson
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

if(ENABLE_HADOOP_ANALYTICS)
  # There's a small dependency on Python for librdkafka's Makefile:
  # https://github.com/edenhill/librdkafka/blob/v0.9.2/Makefile#L8
  find_package(PythonInterp REQUIRED)

  ExternalProject_Add(
    librdkafka
    URL https://github.com/edenhill/librdkafka/archive/v${LIBRDKAFKA_VERSION}.tar.gz
    URL_HASH MD5=${LIBRDKAFKA_HASH}
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
    INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
  )
endif()

list(APPEND RSYSLOG_DEPENDS libestr)
list(APPEND RSYSLOG_DEPENDS libfastjson)
list(APPEND RSYSLOG_DEPENDS liblogging)
if(ENABLE_HADOOP_ANALYTICS)
  list(APPEND RSYSLOG_DEPENDS librdkafka)
endif()

list(APPEND RSYSLOG_CONFIGURE_CMD env)
list(APPEND RSYSLOG_CONFIGURE_CMD LIBESTR_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBESTR_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lestr")
list(APPEND RSYSLOG_CONFIGURE_CMD JSON_C_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include/libfastjson)
list(APPEND RSYSLOG_CONFIGURE_CMD "JSON_C_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lfastjson")
list(APPEND RSYSLOG_CONFIGURE_CMD LIBLOGGING_STDLOG_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBLOGGING_STDLOG_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -llogging-stdlog")
if(ENABLE_HADOOP_ANALYTICS)
  list(APPEND RSYSLOG_CONFIGURE_CMD LIBRDKAFKA_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include)
  list(APPEND RSYSLOG_CONFIGURE_CMD "LIBRDKAFKA_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lrdkafka")
endif()
list(APPEND RSYSLOG_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND RSYSLOG_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-liblogging-stdlog)
list(APPEND RSYSLOG_CONFIGURE_CMD --disable-libgcrypt)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-imptcp)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-impstats)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-mmjsonparse)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-mmutf8fix)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-elasticsearch)
if(ENABLE_HADOOP_ANALYTICS)
  list(APPEND RSYSLOG_CONFIGURE_CMD --enable-omkafka)
endif()

ExternalProject_Add(
  rsyslog
  DEPENDS ${RSYSLOG_DEPENDS}
  URL http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-${RSYSLOG_VERSION}.tar.gz
  URL_HASH SHA256=${RSYSLOG_HASH}
  CONFIGURE_COMMAND rm -rf <BINARY_DIR> && mkdir -p <BINARY_DIR> # Clean across version upgrades
    COMMAND ${RSYSLOG_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND chrpath -d ${STAGE_EMBEDDED_DIR}/sbin/rsyslogd
    COMMAND find ${STAGE_EMBEDDED_DIR}/lib/rsyslog/ -name *.so -exec chrpath -d {} $<SEMICOLON>
)
