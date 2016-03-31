add_custom_target(
  test-web-app-target
  env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} INTEGRATION_TEST_SUITE=true bundle exec rake
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
)

add_custom_target(
  test-web-app
  COMMAND ${CMAKE_BUILD_TOOL} all
  COMMAND ${CMAKE_BUILD_TOOL} test-web-app-target
)
