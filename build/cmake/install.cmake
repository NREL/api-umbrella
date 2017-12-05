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
  PERMISSIONS OWNER_READ GROUP_READ
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
  CODE "
  message(STATUS \"Directories: \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/apps/core/releases/${RELEASE_TIMESTAMP}\")
  execute_process(
    WORKING_DIRECTORY \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/apps/core
    # Multiple commands in execute_process are executed in parallel
    # (http://public.kitware.com/pipermail/cmake/2016-March/063076.html). Since
    # the order of these matter, use a shell wrapper.
    COMMAND sh -c \"rm -rf releases/${RELEASE_TIMESTAMP} && mv releases/0 releases/${RELEASE_TIMESTAMP} && ln -snf releases/${RELEASE_TIMESTAMP} ./current\"
  )
  message(STATUS \"Directories: \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/apps/static-site/releases/${RELEASE_TIMESTAMP}\")
  execute_process(
    WORKING_DIRECTORY \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/apps/static-site
    # Multiple commands in execute_process are executed in parallel
    # (http://public.kitware.com/pipermail/cmake/2016-March/063076.html). Since
    # the order of these matter, use a shell wrapper.
    COMMAND sh -c \"rm -rf releases/${RELEASE_TIMESTAMP} && mv releases/0 releases/${RELEASE_TIMESTAMP} && ln -snf releases/${RELEASE_TIMESTAMP} ./current\"
  )
  message(STATUS \"Directories: \$ENV{DESTDIR}/usr/bin \$ENV{DESTDIR}/var/log \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/etc \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/db \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/log \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/run \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/tmp\")
  execute_process(
    COMMAND mkdir -p \$ENV{DESTDIR}/usr/bin \$ENV{DESTDIR}/var/log \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/etc \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/db \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/log \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/run \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/tmp
  )
  message(STATUS \"Installing: \$ENV{DESTDIR}/usr/bin/api-umbrella\")
  execute_process(
    WORKING_DIRECTORY \$ENV{DESTDIR}/usr/bin
    COMMAND ln -snf ../..${CMAKE_INSTALL_PREFIX}/bin/api-umbrella ./api-umbrella
  )
  message(STATUS \"Installing: \$ENV{DESTDIR}/var/log/api-umbrella\")
  execute_process(
    WORKING_DIRECTORY \$ENV{DESTDIR}/var/log
    COMMAND ln -snf ../..${CMAKE_INSTALL_PREFIX}/var/log ./api-umbrella
  )
  message(STATUS \"Replacing: \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/openresty/luajit/bin/luarocks-5.1 \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/openresty/luajit/bin/luarocks-admin-5.1 \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/openresty/luajit/share/lua/5.1/luarocks/site_config.lua\")
  execute_process(
    COMMAND sed -i \"s#${STAGE_DIR}##g\" \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/openresty/luajit/bin/luarocks-5.1 \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/openresty/luajit/bin/luarocks-admin-5.1 \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/embedded/openresty/luajit/share/lua/5.1/luarocks/site_config.lua
  )
  message(STATUS \"Permissions: \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/tmp\")
  execute_process(
    COMMAND chmod 1777 \$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/var/tmp
  )
  "
  COMPONENT core
)

add_custom_target(install-core
  COMMAND ${CMAKE_COMMAND} -D CMAKE_INSTALL_COMPONENT=core -P ${CMAKE_BINARY_DIR}/cmake_install.cmake
)

add_custom_target(after-install
  COMMAND ${CMAKE_SOURCE_DIR}/build/package/scripts/after-install 1
)
