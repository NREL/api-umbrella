install(
  DIRECTORY ${STAGE_PREFIX_DIR}/
  DESTINATION ${CMAKE_INSTALL_PREFIX}
  USE_SOURCE_PERMISSIONS
  COMPONENT core
)
install(
  PROGRAMS ${CMAKE_SOURCE_DIR}/build/package/files/etc/init.d/api-umbrella
  DESTINATION /etc/init.d
  COMPONENT core
)
install(
  FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/logrotate.d/api-umbrella
  DESTINATION /etc/logrotate.d
  COMPONENT core
)
install(
  FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/sudoers.d/api-umbrella
  DESTINATION /etc/sudoers.d
  COMPONENT core
)

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
  if(NOT EXISTS \$ENV{DESTDIR}/etc/api-umbrella/api-umbrella.yml)
    file(INSTALL ${CMAKE_SOURCE_DIR}/build/package/files/etc/api-umbrella/api-umbrella.yml DESTINATION /etc/api-umbrella)
  else()
    message(STATUS \"Skipping: \$ENV{DESTDIR}/etc/api-umbrella/api-umbrella.yml\")
    file(INSTALL ${CMAKE_SOURCE_DIR}/build/package/files/etc/api-umbrella/api-umbrella.yml DESTINATION /etc/api-umbrella RENAME api-umbrella.yml.default)
  endif()
  "
  COMPONENT core
)

install(
  DIRECTORY ${HADOOP_ANALYTICS_STAGE_PREFIX_DIR}/
  DESTINATION ${CMAKE_INSTALL_PREFIX}
  USE_SOURCE_PERMISSIONS
  COMPONENT hadoop-analytics
)

add_custom_target(
  install-core
  COMMAND ${CMAKE_COMMAND} -D CMAKE_INSTALL_COMPONENT=core -P ${CMAKE_BINARY_DIR}/cmake_install.cmake
)

add_custom_target(
  install-hadoop-analytics
  COMMAND ${CMAKE_COMMAND} -D CMAKE_INSTALL_COMPONENT=hadoop-analytics -P ${CMAKE_BINARY_DIR}/cmake_install.cmake
)
