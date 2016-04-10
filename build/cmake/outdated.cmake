add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
  DEPENDS ${CMAKE_SOURCE_DIR}/build/scripts/Gemfile ${CMAKE_SOURCE_DIR}/build/scripts/Gemfile.lock
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/build/scripts
  COMMAND bundle install --clean --path=${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
    COMMAND touch -c ${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
)

add_custom_target(
  outdated
  DEPENDS ${CMAKE_SOURCE_DIR}/build/scripts/vendor/bundle
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/build/scripts
  COMMAND ${CMAKE_SOURCE_DIR}/build/scripts/outdated
)
