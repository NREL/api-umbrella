add_custom_command(
  OUTPUT
    ${STAMP_DIR}/test-bundle
    ${WORK_DIR}/.bundle
    ${WORK_DIR}/bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/Gemfile
    ${CMAKE_SOURCE_DIR}/Gemfile.lock
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/.bundle bundle install --clean --path=${WORK_DIR}/bundle
  COMMAND touch -c ${WORK_DIR}/.bundle
  COMMAND touch -c ${WORK_DIR}/bundle
  COMMAND touch ${STAMP_DIR}/test-bundle
)

# Normally we perform the bundle out-of-source (so the build takes place
# entirely out of source), but if testing/development is enabled for this
# build, then also create a local ".bundle/config" item within the source. This
# then allows for gems to be found when interacting with the local source
# version of the app.
if(ENABLE_TEST_DEPENDENCIES)
  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/.bundle/config
    DEPENDS
      ${STAMP_DIR}/test-bundle
      ${WORK_DIR}/.bundle
      ${WORK_DIR}/bundle
    COMMAND rm -rf ${CMAKE_SOURCE_DIR}/.bundle
    COMMAND ln -snf ${WORK_DIR}/.bundle ${CMAKE_SOURCE_DIR}/.bundle
    COMMAND touch -c ${CMAKE_SOURCE_DIR}/.bundle/config
  )
  add_custom_target(test-local-bundle ALL DEPENDS ${CMAKE_SOURCE_DIR}/.bundle/config)
endif()
