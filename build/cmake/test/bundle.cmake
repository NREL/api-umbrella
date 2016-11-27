add_custom_command(
  OUTPUT ${STAMP_DIR}/test-bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/Gemfile
    ${CMAKE_SOURCE_DIR}/Gemfile.lock
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --clean --path=${WORK_DIR}/bundle
  COMMAND touch ${STAMP_DIR}/test-bundle
)
