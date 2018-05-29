include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps/luacheck.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps/mailhog.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps/mongo-orchestration.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps/openldap.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps/phantomjs.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps/shellcheck.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/test-deps/unbound.cmake)

add_custom_target(test-deps DEPENDS
  luacheck
  mailhog
  mongo-orchestration
  openldap
  phantomjs
  shellcheck
  unbound
)
