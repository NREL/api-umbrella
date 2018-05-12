# Define a timestamped release name for our app installations. Base this on the
# last git commit timestamp so installs are consistent for each git commit.
get_git_timestamp(RELEASE_TIMESTAMP)

include(${CMAKE_SOURCE_DIR}/build/cmake/app/core.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/app/static-site.cmake)

add_custom_target(app ALL DEPENDS ${STAMP_DIR}/core api_umbrella_static_site)
