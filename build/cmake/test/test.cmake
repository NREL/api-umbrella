add_custom_target(
  test-deps
  DEPENDS ${STAMP_DIR}/test-bundle test-lua-deps
)

add_custom_target(
  test-target
  DEPENDS test-deps
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle exec rake
)

# CMake policy CMP0037 business to allow target named "test".
cmake_policy(PUSH)
if(POLICY CMP0037)
  cmake_policy(SET CMP0037 OLD)
endif()
add_custom_target(
  test
  COMMAND ${CMAKE_BUILD_TOOL} all
  COMMAND ${CMAKE_BUILD_TOOL} test-target
)
cmake_policy(POP)
