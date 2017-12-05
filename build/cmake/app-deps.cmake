include(${CMAKE_SOURCE_DIR}/build/cmake/app-deps/core-lua-deps.cmake)

add_custom_target(app-deps DEPENDS ${STAMP_DIR}/core-lua-deps)
