# Elasticsearch: Analytics database

find_package(Java 1.7 REQUIRED COMPONENTS Runtime)
require_program(rsync)

set(ELASTICSEARCH_VERSION 2.4.6)
set(ELASTICSEARCH_HASH c3441bef89cd91206edf3cf3bd5c4b62550e60a9)

ExternalProject_Add(
  elasticsearch
  EXCLUDE_FROM_ALL 1
  URL https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz
  URL_HASH SHA1=${ELASTICSEARCH_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v --checksum --delete-after <SOURCE_DIR>/ ${STAGE_EMBEDDED_DIR}/elasticsearch/
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/elasticsearch/plugins
)
