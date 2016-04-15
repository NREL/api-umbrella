add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
  DEPENDS ${CMAKE_SOURCE_DIR}/build/scripts/Gemfile ${CMAKE_SOURCE_DIR}/build/scripts/Gemfile.lock bundler
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/build/scripts
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --clean --path=${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
    COMMAND touch -c ${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
)

add_custom_target(
  outdated
  DEPENDS ${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/build/scripts
  COMMAND ${CMAKE_SOURCE_DIR}/build/scripts/outdated
)
