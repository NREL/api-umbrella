# Kylin: Hadoop-based analytics database
ExternalProject_Add(
  kylin
  URL https://archive.apache.org/dist/kylin/apache-kylin-${KYLIN_VERSION}/apache-kylin-${KYLIN_VERSION}-bin.tar.gz
  URL_HASH MD5=${KYLIN_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND mkdir -p ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/kylin
    COMMAND rsync -a <SOURCE_DIR>/ ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/kylin/
)
