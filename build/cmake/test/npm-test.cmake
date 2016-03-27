# CMake policy CMP0037 business to allow target named "test".
cmake_policy(PUSH)
if(POLICY CMP0037)
  cmake_policy(SET CMP0037 OLD)
endif()
add_custom_target(
  test
  env MOCHA_FILES=$ENV{MOCHA_FILES} npm test
  DEPENDS lint
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
  VERBATIM
)
cmake_policy(POP)

