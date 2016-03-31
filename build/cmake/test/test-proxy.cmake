add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/test/node_modules
  DEPENDS ${CMAKE_SOURCE_DIR}/test/package.json
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
  COMMAND npm install
  COMMAND npm prune
)

add_custom_target(
  test-proxy-target
  env MOCHA_FILES=$ENV{MOCHA_FILES} npm test
  DEPENDS ${CMAKE_SOURCE_DIR}/test/node_modules
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
)

add_custom_target(
  test-proxy
  COMMAND ${CMAKE_BUILD_TOOL} all
  COMMAND ${CMAKE_BUILD_TOOL} test-proxy-target
)
