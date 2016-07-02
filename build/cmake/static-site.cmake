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
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build
  DEPENDS api_umbrella_static_site
  COMMAND rm -rf ${STAGE_EMBEDDED_DIR}/apps/static-site/releases
  COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build
  COMMAND rsync -a ${API_UMBRELLA_STATIC_SITE_SOURCE_DIR}/build/ ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build/
  COMMAND touch -c ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build
)

add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/static-site/current
  DEPENDS ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build
  WORKING_DIRECTORY ${STAGE_EMBEDDED_DIR}/apps/static-site
  COMMAND ln -snf releases/${RELEASE_TIMESTAMP} ./current
  COMMAND touch -c ./current
)

add_custom_target(
  static-site-release
  ALL
  DEPENDS
  ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/${RELEASE_TIMESTAMP}/build
  ${STAGE_EMBEDDED_DIR}/apps/static-site/current
)
