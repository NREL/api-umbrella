find_package(Java 1.7 REQUIRED COMPONENTS Runtime)

# Flume: Hadoop log buffering and writing
ExternalProject_Add(
  flume
  URL http://apache.cs.utah.edu/flume/${FLUME_VERSION}/apache-flume-${FLUME_VERSION}-bin.tar.gz
  URL_HASH MD5=${FLUME_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND mkdir -p ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/flume
    COMMAND rsync -a -v --exclude=/docs --exclude=/tools --delete-after --delete-excluded <SOURCE_DIR>/ ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/flume/
)
