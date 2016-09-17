# libgeoip & GeoLiteCityv6.dat: GeoIP locations
ExternalProject_Add(
  libgeoip
  URL https://github.com/maxmind/geoip-api-c/releases/download/v${LIBGEOIP_VERSION}/GeoIP-${LIBGEOIP_VERSION}.tar.gz
  URL_HASH MD5=${LIBGEOIP_HASH}
  CONFIGURE_COMMAND env LDFLAGS=-Wl,-rpath,${STAGE_EMBEDDED_DIR}/lib <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  # Make the project name dynamic based on the current date. This forces a
  # re-download once per day. This helps ensure development and CI environments
  # are using fresh GeoIP data files without downloading on each run.
  geolitecity-${RELEASE_DATE}
  URL https://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND gunzip -c <DOWNLOADED_FILE> > <SOURCE_DIR>/GeoLiteCityv6.dat
  INSTALL_COMMAND install -D -m 644 <SOURCE_DIR>/GeoLiteCityv6.dat ${STAGE_EMBEDDED_DIR}/var/db/geoip/city-v6.dat
    # Since we re-download every day as a separate project name, this cleans up
    # any old downloads in the work directory.
    COMMAND find ${WORK_DIR}/src -maxdepth 1 -name geolitecity* -not -name geolitecity-${RELEASE_DATE}* -print -exec rm -rf {} $<SEMICOLON>
)
