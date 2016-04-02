# Flume: Hadoop log buffering and writing
ExternalProject_Add(
  flume
  URL http://apache.cs.utah.edu/flume/${FLUME_VERSION}/apache-flume-${FLUME_VERSION}-bin.tar.gz
  URL_HASH MD5=${FLUME_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a <SOURCE_DIR>/ ${STAGE_EMBEDDED_DIR}/flume/
)
