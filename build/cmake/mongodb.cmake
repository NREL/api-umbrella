# MongoDB: General database
ExternalProject_Add(
  mongodb
  URL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${MONGODB_VERSION}.tgz
  URL_HASH MD5=${MONGODB_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND rsync -a -v <SOURCE_DIR>/ ${STAGE_EMBEDDED_DIR}/
    # Trim our own distribution by removing some larger files we don't need for
    # API Umbrella.
    COMMAND rm -f ${STAGE_EMBEDDED_DIR}/bin/bsondump ${STAGE_EMBEDDED_DIR}/bin/mongoexport ${STAGE_EMBEDDED_DIR}/bin/mongofiles ${STAGE_EMBEDDED_DIR}/bin/mongoimport ${STAGE_EMBEDDED_DIR}/bin/mongooplog ${STAGE_EMBEDDED_DIR}/bin/mongoperf ${STAGE_EMBEDDED_DIR}/bin/mongos
)
