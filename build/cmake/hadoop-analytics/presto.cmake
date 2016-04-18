find_package(Java 1.7 REQUIRED COMPONENTS Runtime)

# Presto: ANSI-SQL queries against Hadoop Hive tables.
ExternalProject_Add(
  presto
  URL https://repo1.maven.org/maven2/com/facebook/presto/presto-server/${PRESTO_VERSION}/presto-server-${PRESTO_VERSION}.tar.gz
  URL_HASH MD5=${PRESTO_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND mkdir -p ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/presto
    COMMAND rsync -a -v --include=/plugin/hive-hadoop2 --include=/plugin/jmx --exclude=/plugin/* --delete-after --delete-excluded <SOURCE_DIR>/ ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/presto/
)
