add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/test/node_modules
  DEPENDS ${CMAKE_SOURCE_DIR}/test/package.json
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
  COMMAND npm install
  COMMAND npm prune
)

add_custom_target(
  npm-test
  env MOCHA_FILES=$ENV{MOCHA_FILES} npm test
  DEPENDS ${CMAKE_SOURCE_DIR}/test/node_modules
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
  VERBATIM
)
