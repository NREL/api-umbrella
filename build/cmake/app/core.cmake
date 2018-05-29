set(CORE_BUILD_DIR ${WORK_DIR}/src/api-umbrella-core)

include(${CMAKE_SOURCE_DIR}/build/cmake/app/core-admin-ui.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/app/core-web-app.cmake)

# Copy the vendored libraries into the shared build directory.
add_custom_command(
  OUTPUT ${CORE_BUILD_DIR}/shared/vendor
  DEPENDS
    ${STAMP_DIR}/core-web-app-bundle
    ${STAMP_DIR}/core-lua-deps
  COMMAND mkdir -p ${CORE_BUILD_DIR}/shared/vendor
  COMMAND rsync -a --delete-after ${VENDOR_DIR}/ ${CORE_BUILD_DIR}/shared/vendor/
  COMMAND touch -c ${CORE_BUILD_DIR}/shared/vendor
)

# Copy the code into a build release directory.
file(GLOB_RECURSE core_files
  ${CMAKE_SOURCE_DIR}/bin/*
  ${CMAKE_SOURCE_DIR}/config/*
  ${CMAKE_SOURCE_DIR}/templates/*
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/Gemfile*
)
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release-dir
  DEPENDS ${core_files}
  COMMAND mkdir -p ${CORE_BUILD_DIR}/releases/0
  COMMAND rsync -a --delete-after --delete-excluded "--filter=:- ${CMAKE_SOURCE_DIR}/.gitignore" --include=/templates/etc/perp/.boot --exclude=.* --exclude=/templates/etc/test-env* --exclude=/templates/etc/perp/test-env* --exclude=/src/api-umbrella/web-app/spec --exclude=/src/api-umbrella/web-app/app/assets --include=/bin/*** --include=/config/*** --include=/LICENSE.txt --include=/templates/*** --include=/src/*** --exclude=* ${CMAKE_SOURCE_DIR}/ ${CORE_BUILD_DIR}/releases/0/
  COMMAND touch ${STAMP_DIR}/core-build-release-dir
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-build-install-dist
    ${CORE_BUILD_DIR}/releases/0/build/dist/admin-ui
    ${CORE_BUILD_DIR}/releases/0/build/dist/web-app-public
  DEPENDS
    ${STAMP_DIR}/core-admin-ui-build
    ${STAMP_DIR}/core-web-app-build
    ${STAMP_DIR}/core-build-release-dir
  COMMAND mkdir -p ${CORE_BUILD_DIR}/releases/0/build/dist/web-app-public
  COMMAND rsync -a --delete-after ${CORE_BUILD_DIR}/tmp/admin-ui-build/dist/ ${CORE_BUILD_DIR}/releases/0/build/dist/admin-ui/
  COMMAND rsync -a --delete-after ${CORE_BUILD_DIR}/tmp/web-app-public/ ${CORE_BUILD_DIR}/releases/0/build/dist/web-app-public/
  COMMAND rsync -a --delete-after ${CORE_BUILD_DIR}/tmp/web-app-build/web-assets/ ${CORE_BUILD_DIR}/releases/0/build/dist/web-app-public/web-assets/
  COMMAND touch ${STAMP_DIR}/core-build-install-dist
)

# Create a symlink to the latest release.
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-current-symlink
  DEPENDS ${STAMP_DIR}/core-build-release-dir
  WORKING_DIRECTORY ${CORE_BUILD_DIR}
  COMMAND ln -snf releases/0 ./current
  COMMAND touch ${STAMP_DIR}/core-build-current-symlink
)

# Create a symlink to the shared vendor directory within the release.
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release-vendor-symlink
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir
    ${CORE_BUILD_DIR}/shared/vendor
  WORKING_DIRECTORY ${CORE_BUILD_DIR}/releases/0
  COMMAND ln -snf ../../shared/vendor ./vendor
  COMMAND touch ${STAMP_DIR}/core-build-release-vendor-symlink
)

# Copy the gems into the build directory and cleanup for production use.
add_custom_command(
  OUTPUT ${CORE_BUILD_DIR}/releases/0/src/api-umbrella/web-app/.bundle/config
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir
    ${STAMP_DIR}/core-build-release-vendor-symlink
  WORKING_DIRECTORY ${CORE_BUILD_DIR}/releases/0/src/api-umbrella/web-app
  # Disable all non-production gems and remove any old, unused gems.
  COMMAND env PATH=${STAGE_EMBEDDED_PATH} bundle config --local build.nokogiri --use-system-libraries
  COMMAND env PATH=${STAGE_EMBEDDED_PATH} bundle install --path=../../../vendor/bundle --without=development test assets --clean --deployment
  # Purge gem files we don't need to make for a lighter package distribution.
  COMMAND cd ${CORE_BUILD_DIR}/shared/vendor/bundle && rm -rf ruby/*/cache ruby/*/gems/*/test* ruby/*/gems/*/spec ruby/*/bundler/gems/*/test* ruby/*/bundler/gems/*/spec ruby/*/bundler/gems/*/.git
  COMMAND touch -c ${CORE_BUILD_DIR}/releases/0/src/api-umbrella/web-app/.bundle/config
)

#
# Build the release dir.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir
    ${STAMP_DIR}/core-build-release-vendor-symlink
    ${STAMP_DIR}/core-build-current-symlink
    ${CORE_BUILD_DIR}/releases/0/src/api-umbrella/web-app/.bundle/config
  COMMAND touch ${STAMP_DIR}/core-build-release
)

# Copy the built shared directory to the stage install path.
add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/core
  DEPENDS ${CORE_BUILD_DIR}/shared/vendor
  DEPENDS ${STAMP_DIR}/core-build-release
  DEPENDS ${STAMP_DIR}/core-build-install-dist
  COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core
  COMMAND rsync -a --delete-after --delete-excluded --exclude=/tmp ${CORE_BUILD_DIR}/ ${STAGE_EMBEDDED_DIR}/apps/core/
  COMMAND touch -c ${STAGE_EMBEDDED_DIR}/apps/core
)

# Create a symlink for the main "api-umbrella" binary.
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-api-umbrella-bin-symlink
  DEPENDS ${STAGE_EMBEDDED_DIR}/apps/core
  COMMAND mkdir -p ${STAGE_PREFIX_DIR}/bin
  COMMAND cd ${STAGE_PREFIX_DIR}/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella ./api-umbrella
  COMMAND touch ${STAMP_DIR}/core-api-umbrella-bin-symlink
)
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-api-umbrella-env-bin-symlink
  DEPENDS ${STAGE_EMBEDDED_DIR}/apps/core
  COMMAND mkdir -p ${STAGE_PREFIX_DIR}/bin
  COMMAND cd ${STAGE_PREFIX_DIR}/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella-env ./api-umbrella-env
  COMMAND touch ${STAMP_DIR}/core-api-umbrella-env-bin-symlink
)
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-api-umbrella-exec-bin-symlink
  DEPENDS ${STAGE_EMBEDDED_DIR}/apps/core
  COMMAND mkdir -p ${STAGE_PREFIX_DIR}/bin
  COMMAND cd ${STAGE_PREFIX_DIR}/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella-exec ./api-umbrella-exec
  COMMAND touch ${STAMP_DIR}/core-api-umbrella-exec-bin-symlink
)

#
# Install the core app into the stage location.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core
  DEPENDS
    ${STAGE_EMBEDDED_DIR}/apps/core
    ${STAMP_DIR}/core-api-umbrella-bin-symlink
    ${STAMP_DIR}/core-api-umbrella-env-bin-symlink
    ${STAMP_DIR}/core-api-umbrella-exec-bin-symlink
  COMMAND touch ${STAMP_DIR}/core
)
