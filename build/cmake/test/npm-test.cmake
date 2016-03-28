add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/test/node_modules
  DEPENDS ${CMAKE_SOURCE_DIR}/test/package.json
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
  COMMAND npm install
    COMMAND npm prune
)

add_custom_target(
  npm_test
  env MOCHA_FILES=$ENV{MOCHA_FILES} npm test
  DEPENDS lint ${CMAKE_SOURCE_DIR}/test/node_modules
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
  VERBATIM
)

# CMake policy CMP0037 business to allow target named "test".
cmake_policy(PUSH)
if(POLICY CMP0037)
  cmake_policy(SET CMP0037 OLD)
endif()
add_custom_target(
  test
  COMMAND ${CMAKE_BUILD_TOOL} all
    COMMAND ${CMAKE_BUILD_TOOL} npm_test
)
cmake_policy(POP)
