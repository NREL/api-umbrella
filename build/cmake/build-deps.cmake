include(${CMAKE_SOURCE_DIR}/build/cmake/build-deps/nodejs.cmake)

add_custom_target(build-deps ALL DEPENDS nodejs yarn)
