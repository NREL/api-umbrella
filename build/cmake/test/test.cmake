# CMake policy CMP0037 business to allow target named "test".
cmake_policy(PUSH)
if(POLICY CMP0037)
  cmake_policy(SET CMP0037 OLD)
endif()
add_custom_target(
  test
  COMMAND ${CMAKE_BUILD_TOOL} all
  COMMAND ${CMAKE_BUILD_TOOL} luacheck
  COMMAND ${CMAKE_BUILD_TOOL} npm-test
)
cmake_policy(POP)
