# api-umbrella-static-site: Example website content
ExternalProject_Add(
  api_umbrella_static_site
  DEPENDS bundler
  URL https://github.com/NREL/api-umbrella-static-site/archive/${API_UMBRELLA_STATIC_SITE_VERSION}.tar.gz
  URL_HASH MD5=${API_UMBRELLA_STATIC_SITE_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --path=<SOURCE_DIR>/vendor/bundle
    COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle exec middleman build
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(api_umbrella_static_site SOURCE_DIR)
set(API_UMBRELLA_STATIC_SITE_SOURCE_DIR ${SOURCE_DIR})

add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build
  DEPENDS api_umbrella_static_site
  COMMAND rm -rf ${STAGE_EMBEDDED_DIR}/apps/static-site/releases
  COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build
  COMMAND rsync -a ${API_UMBRELLA_STATIC_SITE_SOURCE_DIR}/build/ ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build/
  COMMAND touch -c ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build
)

add_custom_command(
  OUTPUT ${STAMP_DIR}/static-site-current-symlink
  DEPENDS ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build
  WORKING_DIRECTORY ${STAGE_EMBEDDED_DIR}/apps/static-site
  COMMAND ln -snf releases/0 ./current
  COMMAND touch ${STAMP_DIR}/static-site-current-symlink
)

add_custom_target(
  static-site-release
  ALL
  DEPENDS
    ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build
    ${STAMP_DIR}/static-site-current-symlink
)
