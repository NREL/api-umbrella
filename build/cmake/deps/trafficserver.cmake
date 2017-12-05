# TrafficServer: HTTP caching server

# Don't move to TrafficServer 6 until we can verify keepalive behavior:
# https://issues.apache.org/jira/browse/TS-3959
set(TRAFFICSERVER_VERSION 5.3.2)
set(TRAFFICSERVER_HASH c8e5f3e81da643ea79cba0494ed37d45)

list(APPEND TRAFFICSERVER_CONFIGURE_CMD env)
list(APPEND TRAFFICSERVER_CONFIGURE_CMD SPHINXBUILD=false)
list(APPEND TRAFFICSERVER_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND TRAFFICSERVER_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND TRAFFICSERVER_CONFIGURE_CMD --enable-experimental-plugins)

ExternalProject_Add(
  trafficserver
  EXCLUDE_FROM_ALL 1
  URL http://mirror.olnevhost.net/pub/apache/trafficserver/trafficserver-${TRAFFICSERVER_VERSION}.tar.bz2
  URL_HASH MD5=${TRAFFICSERVER_HASH}
  CONFIGURE_COMMAND rm -rf <BINARY_DIR> && mkdir -p <BINARY_DIR> # Clean across version upgrades
    COMMAND ${TRAFFICSERVER_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND chrpath -d ${STAGE_EMBEDDED_DIR}/lib/libtsmgmt.so
    COMMAND find ${STAGE_EMBEDDED_DIR}/libexec/trafficserver/ -name *.so -exec chrpath -d {} $<SEMICOLON>
    COMMAND find ${STAGE_EMBEDDED_DIR}/bin/ -name traffic_* -exec chrpath -d {} $<SEMICOLON>
    COMMAND chrpath -d ${STAGE_EMBEDDED_DIR}/bin/tstop
    # Trim our own distribution by removing some larger files we don't need for
    # API Umbrella.
    COMMAND rm -f ${STAGE_EMBEDDED_DIR}/bin/traffic_sac
)
