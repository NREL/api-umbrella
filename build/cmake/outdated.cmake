add_custom_command(
  OUTPUT ${STAMP_DIR}/outdated-bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/build/scripts/Gemfile
    ${CMAKE_SOURCE_DIR}/build/scripts/Gemfile.lock
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/scripts/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/outdated/.bundle bundle install --clean --path=${WORK_DIR}/src/outdated/bundle
  COMMAND touch ${STAMP_DIR}/outdated-bundle
)

add_custom_target(
  outdated
  DEPENDS ${STAMP_DIR}/outdated-bundle
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/scripts/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/outdated/.bundle ${CMAKE_SOURCE_DIR}/build/scripts/outdated
)
