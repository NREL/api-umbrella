add_custom_target(
  test-web-app-bundle-audit
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle exec bundle-audit check --update
)

add_custom_target(
  test-web-app-brakeman
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle exec brakeman . --format html --output brakeman.html --exit-on-warn
)

add_custom_target(
  test-web-app-rake
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} INTEGRATION_TEST_SUITE=true bundle exec rake
)

add_custom_target(
  test-web-app-target
  COMMAND ${CMAKE_BUILD_TOOL} test-web-app-bundle-audit
  COMMAND ${CMAKE_BUILD_TOOL} test-web-app-brakeman
  COMMAND ${CMAKE_BUILD_TOOL} test-web-app-rake
)

add_custom_target(
  test-web-app
  COMMAND ${CMAKE_BUILD_TOOL} all
  COMMAND ${CMAKE_BUILD_TOOL} test-web-app-target
)
