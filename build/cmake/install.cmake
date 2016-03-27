install(
  DIRECTORY ${CMAKE_SOURCE_DIR}/build/cmake/dest/${CMAKE_INSTALL_PREFIX}/
  DESTINATION ${CMAKE_INSTALL_PREFIX}
  USE_SOURCE_PERMISSIONS
)
install(PROGRAMS ${CMAKE_SOURCE_DIR}/build/package/files/etc/init.d/api-umbrella DESTINATION /etc/init.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/logrotate.d/api-umbrella DESTINATION /etc/logrotate.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/sudoers.d/api-umbrella DESTINATION /etc/sudoers.d)
install(FILES ${CMAKE_SOURCE_DIR}/build/package/files/etc/api-umbrella/api-umbrella.yml DESTINATION /etc/api-umbrella RENAME api-umbrella.yml.default)
