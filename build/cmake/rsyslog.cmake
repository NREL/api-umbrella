# rsyslog: Log buffering and processing
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
  DEPENDS librdkafka
  URL http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-${RSYSLOG_VERSION}.tar.gz
  URL_HASH SHA256=${RSYSLOG_HASH}
  CONFIGURE_COMMAND env "LIBESTR_LIBS=-L/lib64 -lestr" "LIBESTR_CFLAGS=-I/usr/include -I${STAGE_EMBEDDED_DIR}/include" "LDFLAGS=-L${STAGE_EMBEDDED_DIR}/lib -Wl,-rpath,${INSTALL_PREFIX_EMBEDDED}/lib,-rpath,${STAGE_EMBEDDED_DIR}/lib" <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --disable-liblogging-stdlog --enable-imptcp --enable-mmjsonparse --enable-mmutf8fix --enable-elasticsearch --enable-omkafka
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)
