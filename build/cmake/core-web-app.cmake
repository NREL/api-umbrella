add_custom_command(
  OUTPUT ${STAMP_DIR}/core-web-app-bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile.lock
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/web-app/.bundle bundle install --clean --path=${VENDOR_DIR}/bundle
  COMMAND touch ${STAMP_DIR}/core-web-app-bundle
)

# Normally we perform the bundle out-of-source (so the build takes place
# entirely out of source), but if testing/development is enabled for this
# build, then also create a local ".bundle/config" item within the source. This
# then allows for gems to be found when interacting with the local source
# version of the app.
if(ENABLE_TEST_DEPENDENCIES)
  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config
    DEPENDS
      bundler
      ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile
      ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile.lock
    COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile bundle install --clean --path=${VENDOR_DIR}/bundle
    COMMAND touch ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config
  )
  add_custom_target(core-web-app-local-bundle ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config)
endif()

add_custom_command(
  OUTPUT ${STAMP_DIR}/core-web-app-assets-precompiled
  DEPENDS
    ${VENDOR_DIR}/bundle
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/**/*
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/web-app/.bundle RAILS_TMP_PATH=${WORK_DIR}/src/web-app/tmp RAILS_PUBLIC_PATH=${WORK_DIR}/src/web-app/public DEVISE_SECRET_KEY=temp RAILS_SECRET_TOKEN=temp RAILS_GROUPS=assets RAILS_ENV=production bundle exec rake assets:precompile
  COMMAND touch ${STAMP_DIR}/core-web-app-assets-precompiled
)
