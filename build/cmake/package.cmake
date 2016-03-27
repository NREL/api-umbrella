set(CPACK_PACKAGE_VERSION_MAJOR 0)
set(CPACK_PACKAGE_VERSION_MINOR 12)
set(CPACK_PACKAGE_VERSION_PATCH 0)
set(CPACK_RESOURCE_FILE_LICENSE ${CMAKE_SOURCE_DIR}/LICENSE.txt)

if(EXISTS "/etc/redhat-release")
  set(CPACK_GENERATOR RPM)
  set(CPACK_RPM_COMPRESSION_TYPE xz)
  #set(CPACK_RPM_PACKAGE_REQUIRES )
  set(CPACK_RPM_POST_INSTALL_SCRIPT_FILE ${CMAKE_SOURCE_DIR}/build/package/scripts/postinst)
  set(CPACK_RPM_PRE_UNINSTALL_SCRIPT_FILE ${CMAKE_SOURCE_DIR}/build/package/scripts/prerm)
  set(CPACK_RPM_POST_UNINSTALL_SCRIPT_FILE ${CMAKE_SOURCE_DIR}/build/package/scripts/postrm)
endif()

if(EXISTS "/etc/debian_version")
  set(CPACK_GENERATOR DEB)
  set(CPACK_DEBIAN_COMPRESSION_TYPE xz)
  set(
    CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
    ${CMAKE_SOURCE_DIR}/build/package/scripts/postinst
    ${CMAKE_SOURCE_DIR}/build/package/scripts/prerm
    ${CMAKE_SOURCE_DIR}/build/package/scripts/postrm
  )
endif()

include(CPack)
