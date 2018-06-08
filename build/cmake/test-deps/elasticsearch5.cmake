
find_package(Java 1.7 REQUIRED COMPONENTS Runtime)
require_program(rsync)

set(ELASTICSEARCH5_VERSION 5.6.9)
set(ELASTICSEARCH5_HASH 9dae4794cad7b804bffe09d03c94ab25b3e9c586)

ExternalProject_Add(
  elasticsearch5
  EXCLUDE_FROM_ALL 1
  URL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH5_VERSION}.tar.gz
  URL_HASH SHA1=${ELASTICSEARCH5_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v --checksum --delete-after <SOURCE_DIR>/ ${TEST_INSTALL_PREFIX}/elasticsearch5/
    COMMAND chown -R nobody ${TEST_INSTALL_PREFIX}/elasticsearch5
)
