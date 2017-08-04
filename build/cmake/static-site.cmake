# api-umbrella-static-site: Example website content
ExternalProject_Add(
  api_umbrella_static_site
  URL https://github.com/NREL/api-umbrella-static-site/archive/${API_UMBRELLA_STATIC_SITE_VERSION}.tar.gz
  URL_HASH MD5=${API_UMBRELLA_STATIC_SITE_HASH}
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --path=<SOURCE_DIR>/vendor/bundle
  BUILD_COMMAND env PATH=${DEV_INSTALL_PREFIX}/bin:${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle exec middleman build
  INSTALL_COMMAND rm -rf ${STAGE_EMBEDDED_DIR}/apps/static-site/releases
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build
    COMMAND rsync -a <SOURCE_DIR>/build/ ${STAGE_EMBEDDED_DIR}/apps/static-site/releases/0/build/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/static-site && ln -snf releases/0 ./current
)
