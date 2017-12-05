# PostgreSQL: General database

set(POSTGRESQL_VERSION 9.6.6)
set(POSTGRESQL_HASH 399cdffcb872f785ba67e25d275463d74521566318cfef8fe219050d063c8154)

ExternalProject_Add(
  postgresql
  EXCLUDE_FROM_ALL 1
  URL https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.bz2
  URL_HASH SHA256=${POSTGRESQL_HASH}
  CONFIGURE_COMMAND rm -rf <BINARY_DIR> && mkdir -p <BINARY_DIR> # Clean across version upgrades
    COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --disable-rpath --with-system-tzdata=/usr/share/zoneinfo
  BUILD_COMMAND make
    COMMAND cd contrib/pgcrypto && make
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND cd contrib/pgcrypto && make install DESTDIR=${STAGE_DIR}
)
