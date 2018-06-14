find_package(Java 1.7 REQUIRED COMPONENTS Runtime)
require_program(rsync)

set(ELASTICSEARCH6_VERSION 6.2.4)
set(ELASTICSEARCH6_HASH 8db5931278fd7a8687659ebcfaeab0d0f87f7d22)

ExternalProject_Add(
  elasticsearch6
  EXCLUDE_FROM_ALL 1
  URL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH6_VERSION}.tar.gz
  URL_HASH SHA1=${ELASTICSEARCH6_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v --checksum --delete-after <SOURCE_DIR>/ ${TEST_INSTALL_PREFIX}/elasticsearch6/
    COMMAND chown -R nobody ${TEST_INSTALL_PREFIX}/elasticsearch6
)
