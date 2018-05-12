# MongoDB: General database

set(MONGODB_VERSION 3.2.20)
set(MONGODB_HASH 01f7660d86b3de679ce388eaa681286a)

ExternalProject_Add(
  mongodb
  EXCLUDE_FROM_ALL 1
  URL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${MONGODB_VERSION}.tgz
  URL_HASH MD5=${MONGODB_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v <SOURCE_DIR>/ ${STAGE_EMBEDDED_DIR}/
    # Trim our own distribution by removing some larger files we don't need for
    # API Umbrella.
    COMMAND rm -f ${STAGE_EMBEDDED_DIR}/bin/bsondump ${STAGE_EMBEDDED_DIR}/bin/mongoexport ${STAGE_EMBEDDED_DIR}/bin/mongofiles ${STAGE_EMBEDDED_DIR}/bin/mongoimport ${STAGE_EMBEDDED_DIR}/bin/mongooplog ${STAGE_EMBEDDED_DIR}/bin/mongoperf ${STAGE_EMBEDDED_DIR}/bin/mongos
)
