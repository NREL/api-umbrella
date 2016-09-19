set(CORE_BUILD_DIR ${WORK_DIR}/src/api-umbrella-core)

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

# Create the tmp directories in the shared build directory.
#
# We create these more specific tmp sub directories so the deb/rpm
# after-install script can set the necessary permissions on these sub
# directories to allow for deployments of master on top of a package install.
add_custom_command(
  OUTPUT ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/assets
  COMMAND mkdir -p ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/assets
  COMMAND touch -c ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/assets
)
add_custom_command(
  OUTPUT ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/sass
  COMMAND mkdir -p ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/sass
  COMMAND touch -c ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/sass
)
add_custom_command(
  OUTPUT ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/ember-rails
  COMMAND mkdir -p ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/ember-rails
  COMMAND touch -c ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/ember-rails
)

#
# Build the shared dir.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-shared
  DEPENDS
    ${CORE_BUILD_DIR}/shared/vendor
    ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/assets
    ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/cache/sass
    ${CORE_BUILD_DIR}/shared/src/api-umbrella/web-app/tmp/ember-rails
  COMMAND touch ${STAMP_DIR}/core-build-shared
)

# Copy the code into a build release directory.
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release-dir
  COMMAND mkdir -p ${CORE_BUILD_DIR}/releases/0
  COMMAND rsync -a --delete-after --delete-excluded "--filter=:- ${CMAKE_SOURCE_DIR}/.gitignore" --include=/templates/etc/perp/.boot --exclude=.* --exclude=/templates/etc/test-env* --exclude=/templates/etc/perp/test-env* --exclude=/src/api-umbrella/web-app/spec --exclude=/src/api-umbrella/web-app/app/assets --exclude=/src/api-umbrella/hadoop-analytics --include=/bin/*** --include=/config/*** --include=/LICENSE.txt --include=/templates/*** --include=/src/*** --exclude=* ${CMAKE_SOURCE_DIR}/ ${CORE_BUILD_DIR}/releases/0/
  COMMAND touch ${STAMP_DIR}/core-build-release-dir
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
  COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --path=../../../vendor/bundle --without=development test assets --clean --deployment
  # Purge gem files we don't need to make for a lighter package distribution.
  COMMAND cd ${CORE_BUILD_DIR}/shared/vendor/bundle && rm -rf ruby/*/cache ruby/*/gems/*/test* ruby/*/gems/*/spec ruby/*/bundler/gems/*/test* ruby/*/bundler/gems/*/spec ruby/*/bundler/gems/*/.git
  COMMAND touch -c ${CORE_BUILD_DIR}/releases/0/src/api-umbrella/web-app/.bundle/config
)

# Create a symlink to the shared web-app tmp directory within the release.
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release-web-tmp-symlink
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir
		${STAMP_DIR}/core-build-shared
  WORKING_DIRECTORY ${CORE_BUILD_DIR}/releases/0/src/api-umbrella/web-app
  COMMAND ln -snf ../../../../../shared/src/api-umbrella/web-app/tmp ./tmp
  COMMAND touch ${STAMP_DIR}/core-build-release-web-tmp-symlink
)

#
# Build the release dir.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core-build-release
  DEPENDS
    ${STAMP_DIR}/core-build-release-dir
    ${STAMP_DIR}/core-build-release-vendor-symlink
    ${STAMP_DIR}/core-build-release-web-tmp-symlink
    ${STAMP_DIR}/core-build-current-symlink
    ${CORE_BUILD_DIR}/releases/0/src/api-umbrella/web-app/.bundle/config
  COMMAND touch ${STAMP_DIR}/core-build-release
)

# Copy the built shared directory to the stage install path.
add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/core
  DEPENDS ${STAMP_DIR}/core-build-shared
  DEPENDS ${STAMP_DIR}/core-build-release
  COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core
  COMMAND rsync -a --delete-after ${CORE_BUILD_DIR}/ ${STAGE_EMBEDDED_DIR}/apps/core/
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

#
# Install the core app into the stage location.
#
add_custom_command(
  OUTPUT ${STAMP_DIR}/core
  DEPENDS
    ${STAGE_EMBEDDED_DIR}/apps/core
    ${STAMP_DIR}/core-api-umbrella-bin-symlink
  COMMAND touch ${STAMP_DIR}/core
)

add_custom_target(core ALL DEPENDS ${STAMP_DIR}/core)
