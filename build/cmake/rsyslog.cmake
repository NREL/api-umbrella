# rsyslog: Log buffering and processing

find_package(CURL REQUIRED)
pkg_check_modules(JSON_C REQUIRED json-c)
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
  librdkafka
  URL https://github.com/edenhill/librdkafka/archive/${LIBRDKAFKA_VERSION}.tar.gz
  URL_HASH MD5=${LIBRDKAFKA_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  rsyslog
  DEPENDS libestr librdkafka
  URL http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-${RSYSLOG_VERSION}.tar.gz
  URL_HASH SHA256=${RSYSLOG_HASH}
  CONFIGURE_COMMAND env "LIBESTR_LIBS=-L${STAGE_EMBEDDED_DIR}/lib -lestr" "LIBESTR_CFLAGS=-I${STAGE_EMBEDDED_DIR}/include" "LDFLAGS=-L${STAGE_EMBEDDED_DIR}/lib -Wl,-rpath,${INSTALL_PREFIX_EMBEDDED}/lib,-rpath,${STAGE_EMBEDDED_DIR}/lib" <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --disable-liblogging-stdlog --disable-libgcrypt --enable-imptcp --enable-mmjsonparse --enable-mmutf8fix --enable-elasticsearch --enable-omkafka
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)
