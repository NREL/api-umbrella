add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-web-app-bundle
    ${WORK_DIR}/src/web-app/.bundle
    ${VENDOR_DIR}/bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile.lock
  COMMAND env PATH=${STAGE_EMBEDDED_PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/web-app/.bundle bundle config --local build.nokogiri --use-system-libraries
  COMMAND env PATH=${STAGE_EMBEDDED_PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/web-app/.bundle bundle install --path=${VENDOR_DIR}/bundle
  COMMAND touch -c ${WORK_DIR}/src/web-app/.bundle
  COMMAND touch -c ${VENDOR_DIR}/bundle
  COMMAND touch ${STAMP_DIR}/core-web-app-bundle
)

file(GLOB_RECURSE web_app_public_files
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/public/*.html
)
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-web-app-public
  DEPENDS ${web_app_public_files}
  COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/web-app-public
  COMMAND rsync -a --delete-after ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/public/ ${CORE_BUILD_DIR}/tmp/web-app-public/
  COMMAND touch ${STAMP_DIR}/core-web-app-public
)

file(GLOB_RECURSE web_asset_files
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/*.css
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/*.scss
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/*.erb
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/*.js
)
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-web-app-precompile
  DEPENDS
    ${STAMP_DIR}/core-web-app-bundle
    ${web_asset_files}
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/config/initializers/assets.rb
  COMMAND env PATH=${STAGE_EMBEDDED_PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/web-app/.bundle RAILS_TMP_PATH=${CORE_BUILD_DIR}/tmp/web-app-tmp RAILS_PUBLIC_PATH=${CORE_BUILD_DIR}/tmp/web-app-build RAILS_ENV=production RAILS_SECRET_TOKEN=temp RAILS_ASSETS_PRECOMPILE=true bundle exec rake -f ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Rakefile assets:clobber assets:precompile
  COMMAND touch ${STAMP_DIR}/core-web-app-precompile
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-web-app-build
  DEPENDS
    ${STAMP_DIR}/core-web-app-public
    ${STAMP_DIR}/core-web-app-precompile
  COMMAND touch ${STAMP_DIR}/core-web-app-build
)
