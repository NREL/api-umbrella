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

add_custom_target(test-bundle DEPENDS
  ${STAMP_DIR}/test-bundle
)

add_custom_target(test DEPENDS
  deps
  build-deps
  app-deps
  test-deps
  test-bundle
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/.bundle bundle exec rake
)
