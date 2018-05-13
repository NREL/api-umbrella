add_custom_command(
  OUTPUT ${STAMP_DIR}/package-bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/build/package/Gemfile
    ${CMAKE_SOURCE_DIR}/build/package/Gemfile.lock
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:${DEFAULT_PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/package/.bundle bundle config --local build.nokogiri --use-system-libraries
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:${DEFAULT_PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/package/.bundle bundle install --path=${VENDOR_DIR}/bundle
  COMMAND touch ${STAMP_DIR}/package-bundle
)

add_custom_target(package-core
  DEPENDS ${STAMP_DIR}/package-bundle
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
  COMMAND make
  COMMAND make install-core DESTDIR=${WORK_DIR}/package-dest-core
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:${DEFAULT_PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/package/.bundle WORK_DIR=${WORK_DIR} PACKAGE_WORK_DIR=${PACKAGE_WORK_DIR} PACKAGE=core ${CMAKE_SOURCE_DIR}/build/package/build_package
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
)

add_custom_target(package DEPENDS package-core)
