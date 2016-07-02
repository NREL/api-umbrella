add_custom_target(
  clean-download-archives
  COMMAND rm -f ${WORK_DIR}/src/*.gz ${WORK_DIR}/src/*.bz2 ${WORK_DIR}/src/*.tgz
)
