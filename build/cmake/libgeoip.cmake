# libgeoip & GeoLiteCityv6.dat: GeoIP locations
list(APPEND LIBGEOIP_CONFIGURE_CMD env)
list(APPEND LIBGEOIP_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND LIBGEOIP_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})

ExternalProject_Add(
  libgeoip
  URL https://github.com/maxmind/geoip-api-c/releases/download/v${LIBGEOIP_VERSION}/GeoIP-${LIBGEOIP_VERSION}.tar.gz
  URL_HASH MD5=${LIBGEOIP_HASH}
  CONFIGURE_COMMAND ${LIBGEOIP_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND find ${STAGE_EMBEDDED_DIR}/bin/ -name geoiplookup* -exec chrpath -d {} $<SEMICOLON>
)

ExternalProject_Add(
  # Make the project name dynamic based on the current date. This forces a
  # re-download once per day. This helps ensure development and CI environments
  # are using fresh GeoIP data files without downloading on each run.
  geolitecity-${RELEASE_DATE}
  URL https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
  DOWNLOAD_NO_EXTRACT 1
  # Since we re-download every day as a separate project name, this cleans up
  # any old downloads in the work directory.
  CONFIGURE_COMMAND find ${CMAKE_BINARY_DIR}/${EP_BASE} -maxdepth 2 -name geolitecity* -not -name geolitecity-${RELEASE_DATE}* -print -exec rm -rf {} $<SEMICOLON>
  BUILD_COMMAND gunzip -c <DOWNLOADED_FILE> > <BINARY_DIR>/GeoLite2-City.tar
  INSTALL_COMMAND install -D -m 644 <BINARY_DIR>/GeoLite2-City.tar ${STAGE_EMBEDDED_DIR}/var/db/geoip/city-v6.dat
)
