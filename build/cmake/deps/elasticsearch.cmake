# Elasticsearch: Analytics database

find_package(Java 1.7 REQUIRED COMPONENTS Runtime)
require_program(rsync)

set(ELASTICSEARCH_VERSION 6.0.1)
set(ELASTICSEARCH_HASH b86a04acd194e7e96e3a32de6ab4983d6569ffb1714f2af9e2b49623004987e13e57c5db055153a188f5d2d7eea63d649fa87769f7625f3fc4923e0cd5b8f3ee)

ExternalProject_Add(
  elasticsearch
  EXCLUDE_FROM_ALL 1
  URL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz
  URL_HASH SHA512=${ELASTICSEARCH_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v --checksum --delete-after <SOURCE_DIR>/ ${STAGE_EMBEDDED_DIR}/elasticsearch/
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/elasticsearch/plugins
)
