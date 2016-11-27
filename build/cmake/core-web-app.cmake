add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-web-app-bundle
    ${WORK_DIR}/src/web-app/.bundle
    ${VENDOR_DIR}/bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile.lock
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/web-app/.bundle bundle install --clean --path=${VENDOR_DIR}/bundle
  COMMAND touch -c ${WORK_DIR}/src/web-app/.bundle
  COMMAND touch -c ${VENDOR_DIR}/bundle
  COMMAND touch ${STAMP_DIR}/core-web-app-bundle
)

file(GLOB_RECURSE web_asset_files
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/*.css
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/*.erb
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/*.js
)
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-web-app-precompile
  DEPENDS
    ${STAMP_DIR}/core-web-app-bundle
    ${web_asset_files}
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/config/initializers/assets.rb
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/web-app/.bundle RAILS_TMP_PATH=/tmp/web-app-build RAILS_PUBLIC_PATH=${CORE_BUILD_DIR}/tmp/web-app-build bundle exec rake -f ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Rakefile assets:clobber assets:precompile
  COMMAND touch ${STAMP_DIR}/core-web-app-precompile
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
      ${STAMP_DIR}/core-web-app-bundle
      ${WORK_DIR}/src/web-app/.bundle
      ${VENDOR_DIR}/bundle
    COMMAND rm -rf ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle
    COMMAND ln -snf ${WORK_DIR}/src/web-app/.bundle ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle
    COMMAND touch -c ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config
  )
  add_custom_target(core-web-app-local-bundle ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config)
endif()
