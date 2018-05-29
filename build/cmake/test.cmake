add_custom_target(test DEPENDS
  deps
  build-deps
  app-deps
  test-deps
  test-bundle
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:${DEFAULT_PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/.bundle bundle exec rake
)
