add_custom_command(
  OUTPUT
    ${STAMP_DIR}/test-legacy-npm-install
    ${CORE_BUILD_DIR}/tmp/test-legacy-npm/node_modules
    ${CMAKE_SOURCE_DIR}/test/legacy/node_modules
  DEPENDS
    nodejs_test
    ${CMAKE_SOURCE_DIR}/test/legacy/package.json
  COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/test-legacy-npm
  COMMAND cp ${CMAKE_SOURCE_DIR}/test/legacy/package.json ${CORE_BUILD_DIR}/tmp/test-legacy-npm/
  COMMAND cd ${CORE_BUILD_DIR}/tmp/test-legacy-npm && env PATH=${TEST_INSTALL_PREFIX}/bin:$ENV{PATH} npm install && env PATH=${TEST_INSTALL_PREFIX}/bin:$ENV{PATH} npm prune
  COMMAND ln -sf ${CORE_BUILD_DIR}/tmp/test-legacy-npm/node_modules ${CMAKE_SOURCE_DIR}/test/legacy/node_modules
  COMMAND touch ${STAMP_DIR}/test-legacy-npm-install
)

add_custom_target(
  test-legacy-target
  COMMAND env PATH=${TEST_INSTALL_PREFIX}/bin:$ENV{PATH} npm test
  DEPENDS ${STAMP_DIR}/test-legacy-npm-install
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test/legacy
)

add_custom_target(
  test-legacy
  COMMAND ${CMAKE_BUILD_TOOL} all
  COMMAND ${CMAKE_BUILD_TOOL} test-legacy-target
)
