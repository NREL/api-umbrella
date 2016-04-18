add_custom_command(
  OUTPUT ${STAMP_DIR}/package-bundle
  DEPENDS
    bundler
    ${CMAKE_SOURCE_DIR}/build/package/Gemfile
    ${CMAKE_SOURCE_DIR}/build/package/Gemfile.lock
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/package/.bundle bundle install --clean --path=${WORK_DIR}/src/package/bundle
  COMMAND touch ${STAMP_DIR}/package-bundle
)

add_custom_target(
  package-core
  DEPENDS ${STAMP_DIR}/package-bundle
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
  COMMAND make
  COMMAND make install-core DESTDIR=${WORK_DIR}/package-dest-core
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/package/.bundle WORK_DIR=${WORK_DIR} PACKAGE=core ${CMAKE_SOURCE_DIR}/build/package/build_package
  COMMAND rm -rf ${WORK_DIR}/package-dest-core
)

add_custom_target(
  package-hadoop-analytics
  DEPENDS ${STAMP_DIR}/package-bundle
  COMMAND rm -rf ${WORK_DIR}/package-dest-hadoop-analytics
  COMMAND make
  COMMAND make install-hadoop-analytics DESTDIR=${WORK_DIR}/package-dest-hadoop-analytics
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} BUNDLE_GEMFILE=${CMAKE_SOURCE_DIR}/build/package/Gemfile BUNDLE_APP_CONFIG=${WORK_DIR}/src/package/.bundle WORK_DIR=${WORK_DIR} PACKAGE=hadoop-analytics ${CMAKE_SOURCE_DIR}/build/package/build_package
  COMMAND rm -rf ${WORK_DIR}/package-dest-hadoop-analytics
)

# CMake policy CMP0037 to allow target named "package".
cmake_policy(PUSH)
if(POLICY CMP0037)
  cmake_policy(SET CMP0037 OLD)
endif()
add_custom_target(
  package
  COMMAND ${CMAKE_BUILD_TOOL} package-core
  COMMAND ${CMAKE_BUILD_TOOL} package-hadoop-analytics
)
cmake_policy(POP)
