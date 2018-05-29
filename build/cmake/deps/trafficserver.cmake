# TrafficServer: HTTP caching server

set(TRAFFICSERVER_VERSION 7.1.3)
set(TRAFFICSERVER_HASH 1ddb23a1c0564929d2246ff3cd97595a9d0b1891736a9d0ef8ca56f52a7b86159b657bbc22f2e64aaccee13009ceff2a47c92b8b25121d65c7ccfdedf8b084ea)

list(APPEND TRAFFICSERVER_CONFIGURE_CMD env)
list(APPEND TRAFFICSERVER_CONFIGURE_CMD SPHINXBUILD=false)
list(APPEND TRAFFICSERVER_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND TRAFFICSERVER_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND TRAFFICSERVER_CONFIGURE_CMD --enable-experimental-plugins)

ExternalProject_Add(
  trafficserver
  EXCLUDE_FROM_ALL 1
  URL http://mirror.olnevhost.net/pub/apache/trafficserver/trafficserver-${TRAFFICSERVER_VERSION}.tar.bz2
  URL_HASH SHA512=${TRAFFICSERVER_HASH}
  CONFIGURE_COMMAND rm -rf <BINARY_DIR> && mkdir -p <BINARY_DIR> # Clean across version upgrades
    COMMAND ${TRAFFICSERVER_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
    COMMAND chrpath -d ${STAGE_EMBEDDED_DIR}/lib/libtsmgmt.so
    COMMAND find ${STAGE_EMBEDDED_DIR}/libexec/trafficserver/ -name *.so -exec chrpath -d {} $<SEMICOLON>
    COMMAND find ${STAGE_EMBEDDED_DIR}/bin/ -name traffic_* -exec chrpath -d {} $<SEMICOLON>
)
