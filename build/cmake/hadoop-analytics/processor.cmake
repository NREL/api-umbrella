find_package(Java 1.7 REQUIRED COMPONENTS Runtime)
find_package(Java 1.7 REQUIRED COMPONENTS Development)

ExternalProject_Add(
  maven
  URL http://apache.mirrors.ionfish.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
  URL_HASH MD5=${MAVEN_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(maven SOURCE_DIR)
set(MAVEN_SOURCE_DIR ${SOURCE_DIR})

add_custom_command(
  OUTPUT ${STAMP_DIR}/hadoop-analytics-processor
  DEPENDS
    maven
  COMMAND mkdir -p ${WORK_DIR}/src/hadoop-analytics
  COMMAND env PATH=${MAVEN_SOURCE_DIR}/bin:$ENV{PATH} mvn -f ${CMAKE_SOURCE_DIR}/src/api-umbrella/hadoop-analytics/pom.xml clean package -DbuildDir=${WORK_DIR}/src/hadoop-analytics
  COMMAND mkdir -p ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/hadoop-analytics
  COMMAND cp ${WORK_DIR}/src/hadoop-analytics/processor/processor-0.0.1-SNAPSHOT.jar ${HADOOP_ANALYTICS_STAGE_EMBEDDED_DIR}/hadoop-analytics/processor.jar
  COMMAND touch ${STAMP_DIR}/hadoop-analytics-processor
)
add_custom_target(hadoop-analytics-processor ALL DEPENDS ${STAMP_DIR}/hadoop-analytics-processor)
