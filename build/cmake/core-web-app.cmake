add_custom_command(
  OUTPUT ${WORK_DIR}/vendor/bundle ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config
  DEPENDS bundler ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile.lock
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --clean --path=${WORK_DIR}/vendor/bundle
  COMMAND touch -c ${WORK_DIR}/vendor/bundle ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config
)
add_custom_target(web_app_bundle_install ALL DEPENDS ${WORK_DIR}/vendor/bundle ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/.bundle/config)

add_custom_command(
  OUTPUT ${WORK_DIR}/tmp/web-app-precompiled-assets
  DEPENDS web_app_bundle_install ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/app/assets/**/*
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} DEVISE_SECRET_KEY=temp RAILS_SECRET_TOKEN=temp bundle exec rake assets:precompile
  COMMAND mkdir -p ${WORK_DIR}/tmp/web-app-precompiled-assets
  COMMAND rsync -a --delete-after public/web-assets/ ${WORK_DIR}/tmp/web-app-precompiled-assets/
  COMMAND rm -rf public/web-assets
  COMMAND touch -c ${WORK_DIR}/tmp/web-app-precompiled-assets
)
add_custom_target(web_app_assets_precompile ALL DEPENDS ${WORK_DIR}/tmp/web-app-precompiled-assets)
