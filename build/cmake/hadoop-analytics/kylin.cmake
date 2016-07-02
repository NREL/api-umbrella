find_package(Java 1.7 REQUIRED COMPONENTS Runtime)

# Kylin: Hadoop-based analytics database
ExternalProject_Add(
  kylin
  URL http://mirrors.sonic.net/apache/kylin/apache-kylin-${KYLIN_VERSION}/apache-kylin-${KYLIN_VERSION}-bin.tar.gz
  URL_HASH MD5=${KYLIN_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND mkdir -p ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/kylin
    COMMAND rsync -a -v --exclude=/sample_cube --delete-after --delete-excluded <SOURCE_DIR>/ ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/kylin/
)
