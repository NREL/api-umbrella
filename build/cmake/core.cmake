set(CORE_BUILD_DIR ${WORK_DIR}/src/api-umbrella-core)
set(CORE_RELEASE_BUILD_DIR ${CORE_BUILD_DIR}/releases/0)
set(CORE_SHARED_BUILD_DIR ${CORE_BUILD_DIR}/shared)

# Copy the vendored libraries into the shared build directory.
add_custom_command(
  OUTPUT ${CORE_SHARED_BUILD_DIR}/vendor
  DEPENDS
    ${STAMP_DIR}/core-web-app-bundle
    ${STAMP_DIR}/core-lua-deps
  COMMAND mkdir -p ${CORE_SHARED_BUILD_DIR}/vendor
  COMMAND rsync -av --delete-after ${VENDOR_DIR}/ ${CORE_SHARED_BUILD_DIR}/vendor/
  COMMAND touch -c ${CORE_SHARED_BUILD_DIR}/vendor
)

# Copy the precompiled assets into the shared build directory.
add_custom_command(
  OUTPUT ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
  DEPENDS ${STAMP_DIR}/core-web-app-assets-precompiled
  COMMAND mkdir -p ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
  COMMAND rsync -av --delete-after ${WORK_DIR}/src/web-app/public/web-assets/ ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets/
  COMMAND touch -c ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
)

# Create a tmp directory in the shared build directory.
add_custom_command(
  OUTPUT ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/tmp
  COMMAND mkdir -p ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/tmp
  COMMAND touch -c ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/tmp
)

#
# Build the shared dir.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-shared
  DEPENDS
    ${CORE_SHARED_BUILD_DIR}/vendor
    ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
    ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/tmp
  COMMAND touch ${STAMP_DIR}/core-build-shared
)

# Copy the code into a build release directory.
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release-dir-${RELEASE_TIMESTAMP}
  COMMAND mkdir -p ${CORE_RELEASE_BUILD_DIR}
  COMMAND rsync -av --delete-after --delete-excluded "--filter=:- ${CMAKE_SOURCE_DIR}/.gitignore" --include=/templates/etc/perp/.boot --exclude=.* --exclude=/templates/etc/test-env* --exclude=/templates/etc/perp/test-env* --exclude=/src/api-umbrella/web-app/spec --exclude=/src/api-umbrella/web-app/app/assets --exclude=/src/api-umbrella/hadoop-analytics --include=/bin/*** --include=/config/*** --include=/LICENSE.txt --include=/templates/*** --include=/src/*** --exclude=* ${CMAKE_SOURCE_DIR}/ ${CORE_RELEASE_BUILD_DIR}/
  COMMAND rm -f ${STAMP_DIR}/core-build-release-dir*
  COMMAND touch ${STAMP_DIR}/core-build-release-dir-${RELEASE_TIMESTAMP}
)

# Create a symlink to the shared vendor directory within the release.
add_custom_command(
  OUTPUT ${CORE_RELEASE_BUILD_DIR}/vendor
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir-${RELEASE_TIMESTAMP}
    ${CORE_SHARED_BUILD_DIR}/vendor
  WORKING_DIRECTORY ${CORE_RELEASE_BUILD_DIR}
  COMMAND ln -snf ../../shared/vendor ./vendor
  COMMAND touch -c ${CORE_RELEASE_BUILD_DIR}/vendor
)

# Copy the gems into the build directory and cleanup for production use.
add_custom_command(
  OUTPUT ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/.bundle/config
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir-${RELEASE_TIMESTAMP}
    ${CORE_RELEASE_BUILD_DIR}/vendor
  WORKING_DIRECTORY ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app
  # Disable all non-production gems and remove any old, unused gems.
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --path=../../../vendor/bundle --without=development test assets --clean --deployment
  # Purge gem files we don't need to make for a lighter package distribution.
  COMMAND cd ${CORE_SHARED_BUILD_DIR}/vendor/bundle && rm -rf ruby/*/cache ruby/*/gems/*/test* ruby/*/gems/*/spec ruby/*/bundler/gems/*/test* ruby/*/bundler/gems/*/spec ruby/*/bundler/gems/*/.git
  COMMAND touch -c ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/.bundle/config
)

# Create a symlink to the shared assets directory within the release.
add_custom_command(
  OUTPUT ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir-${RELEASE_TIMESTAMP}
    ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
  WORKING_DIRECTORY ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/public
  COMMAND ln -snf ../../../../../../shared/src/api-umbrella/web-app/public/web-assets ./web-assets
  COMMAND touch -c ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
)

# Create a symlink to the shared web-app tmp directory within the release.
add_custom_command(
  OUTPUT ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/tmp
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir-${RELEASE_TIMESTAMP}
    ${CORE_SHARED_BUILD_DIR}/src/api-umbrella/web-app/tmp
  WORKING_DIRECTORY ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app
  COMMAND ln -snf ../../../../../shared/src/api-umbrella/web-app/tmp ./tmp
  COMMAND touch -c ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/tmp
)

#
# Build the release dir.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir-${RELEASE_TIMESTAMP}
    ${CORE_RELEASE_BUILD_DIR}/vendor
    ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/.bundle/config
    ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/public/web-assets
    ${CORE_RELEASE_BUILD_DIR}/src/api-umbrella/web-app/tmp
  COMMAND touch ${STAMP_DIR}/core-build-release
)

# Copy the built shared directory to the stage install path.
add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/core/shared
  DEPENDS ${STAMP_DIR}/core-build-shared
  COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/shared
  COMMAND rsync -av --delete-after ${CORE_SHARED_BUILD_DIR}/ ${STAGE_EMBEDDED_DIR}/apps/core/shared/
  COMMAND touch -c ${STAGE_EMBEDDED_DIR}/apps/core/shared
)

# Copy the built release directory to the stage install path.
add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
  DEPENDS ${STAMP_DIR}/core-build-release
  COMMAND rm -rf ${STAGE_EMBEDDED_DIR}/apps/core/releases
  COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
  COMMAND rsync -a ${CORE_RELEASE_BUILD_DIR}/ ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/
  COMMAND touch -c ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
)

# Create a symlink to the latest release.
add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/core/current
  DEPENDS ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
  WORKING_DIRECTORY ${STAGE_EMBEDDED_DIR}/apps/core
  COMMAND ln -snf releases/${RELEASE_TIMESTAMP} ./current
  COMMAND touch -c ./current
)

# Create a symlink for the main "api-umbrella" binary.
add_custom_command(
  OUTPUT ${STAGE_PREFIX_DIR}/bin/api-umbrella
  DEPENDS ${STAGE_EMBEDDED_DIR}/apps/core/current
  COMMAND mkdir -p ${STAGE_PREFIX_DIR}/bin
  COMMAND cd ${STAGE_PREFIX_DIR}/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella ./api-umbrella
  COMMAND touch -c ${STAGE_PREFIX_DIR}/bin/api-umbrella
)

#
# Install the core app into the stage location.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core
  DEPENDS
    ${STAGE_EMBEDDED_DIR}/apps/core/shared
    ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
    ${STAGE_EMBEDDED_DIR}/apps/core/current
    ${STAGE_PREFIX_DIR}/bin/api-umbrella
  COMMAND touch ${STAMP_DIR}/core
)

add_custom_target(core ALL DEPENDS ${STAMP_DIR}/core)
