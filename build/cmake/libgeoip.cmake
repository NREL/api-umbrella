# libgeoip & GeoLiteCityv6.dat: GeoIP locations
ExternalProject_Add(
  libgeoip
  URL https://github.com/maxmind/geoip-api-c/releases/download/v${LIBGEOIP_VERSION}/GeoIP-${LIBGEOIP_VERSION}.tar.gz
  URL_HASH MD5=${LIBGEOIP_HASH}
  CONFIGURE_COMMAND env LDFLAGS=-Wl,-rpath,${STAGE_EMBEDDED_DIR}/lib <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  geolitecity
  DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz
    COMMAND cd <SOURCE_DIR> && gunzip -c GeoLiteCityv6.dat.gz > GeoLiteCityv6.dat
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/GeoLiteCityv6.dat ${STAGE_EMBEDDED_DIR}/var/db/geoip/city-v6.dat
)
