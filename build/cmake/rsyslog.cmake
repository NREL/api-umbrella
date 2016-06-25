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

# Build json-c, since Ubuntu 12.04 doesn't offer this as a package, and once we
# upgrade to newer versions of rsyslog, we'll need to switch to libfastjson and
# build that from source anyway (since there are no system packages for that).
ExternalProject_Add(
  json-c
  URL https://s3.amazonaws.com/json-c_releases/releases/json-c-${JSON_C_VERSION}-nodoc.tar.gz
  URL_HASH SHA256=${JSON_C_HASH}
  BUILD_IN_SOURCE 1
  # Run autoreconf to fix issues with the bundled configure file being built
  # with specific versions of autoreconf and libtool that might be newer than
  # the default OS packages.
  CONFIGURE_COMMAND autoreconf --force --install -v
    COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

if(ENABLE_HADOOP_ANALYTICS)
  # There's a small dependency on Python for librdkafka's Makefile:
  # https://github.com/edenhill/librdkafka/blob/0.9.1/Makefile#L8
  find_package(PythonInterp REQUIRED)

  ExternalProject_Add(
    librdkafka
    URL https://github.com/edenhill/librdkafka/archive/${LIBRDKAFKA_VERSION}.tar.gz
    URL_HASH MD5=${LIBRDKAFKA_HASH}
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
    INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
  )
endif()

list(APPEND RSYSLOG_DEPENDS json-c)
list(APPEND RSYSLOG_DEPENDS libestr)
if(ENABLE_HADOOP_ANALYTICS)
  list(APPEND RSYSLOG_DEPENDS librdkafka)
endif()

# --with-moddirs required to allow things to work in staged location, as well
# as install location. Extra CFLAGS are needed when --with-moddirs is given
# (since these default values go missing).
list(APPEND RSYSLOG_CONFIGURE_CMD env)
list(APPEND RSYSLOG_CONFIGURE_CMD LIBESTR_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include)
list(APPEND RSYSLOG_CONFIGURE_CMD "LIBESTR_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lestr")
list(APPEND RSYSLOG_CONFIGURE_CMD JSON_C_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include/json-c)
list(APPEND RSYSLOG_CONFIGURE_CMD "JSON_C_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -ljson-c")
list(APPEND RSYSLOG_CONFIGURE_CMD "CFLAGS=-I<SOURCE_DIR> -I<SOURCE_DIR>/grammar")
list(APPEND RSYSLOG_CONFIGURE_CMD "LDFLAGS=-L${STAGE_EMBEDDED_DIR}/lib -Wl,-rpath,${INSTALL_PREFIX_EMBEDDED}/lib")
list(APPEND RSYSLOG_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND RSYSLOG_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND RSYSLOG_CONFIGURE_CMD --with-moddirs=${STAGE_EMBEDDED_DIR}/lib/rsyslog)
list(APPEND RSYSLOG_CONFIGURE_CMD --disable-liblogging-stdlog)
list(APPEND RSYSLOG_CONFIGURE_CMD --disable-libgcrypt)
list(APPEND RSYSLOG_CONFIGURE_CMD --enable-imptcp)
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
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${RSYSLOG_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)
