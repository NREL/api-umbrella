# PostgreSQL: General database
ExternalProject_Add(
  postgresql
  URL https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.bz2
  URL_HASH SHA256=${POSTGRESQL_HASH}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --disable-rpath --with-system-tzdata=/usr/share/zoneinfo
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)
