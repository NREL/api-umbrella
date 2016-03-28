install(
  DIRECTORY ${STAGE_PREFIX_DIR}/
  DESTINATION ${CMAKE_INSTALL_PREFIX}
  USE_SOURCE_PERMISSIONS
)
install(PROGRAMS ${CMAKE_SOURCE_DIR}/build/package/files/etc/init.d/api-umbrella DESTINATION /etc/init.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/logrotate.d/api-umbrella DESTINATION /etc/logrotate.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/sudoers.d/api-umbrella DESTINATION /etc/sudoers.d)

# If /etc/api-umbrella/api-umbrella.yml doesn't exist, install it.
#
# If /etc/api-umbrella/api-umbrella.yml does exist, install the default version
# to api-umbrella.yml.default (so it's available for reference, but we don't
# overwrite any local changes).
#
# The CODE block is so that this conditional is deferred until install time
# (rather than when cmake builds the makefile). See:
# https://cmake.org/Bug/view.php?id=12646
install(
  CODE "
  if(NOT EXISTS /etc/api-umbrella/api-umbrella.yml)
    file(INSTALL ${CMAKE_SOURCE_DIR}/build/package/files/etc/api-umbrella/api-umbrella.yml DESTINATION /etc/api-umbrella)
  else()
    message(STATUS \"Skipping: /etc/api-umbrella/api-umbrella.yml\")
    file(INSTALL ${CMAKE_SOURCE_DIR}/build/package/files/etc/api-umbrella/api-umbrella.yml DESTINATION /etc/api-umbrella RENAME api-umbrella.yml.default)
  endif()
  "
)
