add_custom_command(
  OUTPUT ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
  DEPENDS web_app_assets_precompile
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app
	# Create a new release directory, copying the relevant source code from the
	# current repo checkout into the release (but excluding tests, etc).
  COMMAND rm -rf ${STAGE_EMBEDDED_DIR}/apps/core/releases
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}
    COMMAND	rsync -a "--filter=:- ${CMAKE_SOURCE_DIR}/.gitignore" --include=/templates/etc/perp/.boot --exclude=.* --exclude=/templates/etc/test-env* --exclude=/templates/etc/perp/test-env* --exclude=/src/api-umbrella/web-app/spec --exclude=/src/api-umbrella/web-app/app/assets --exclude=/src/api-umbrella/hadoop-analytics --include=/bin/*** --include=/config/*** --include=/LICENSE.txt --include=/templates/*** --include=/src/*** --exclude=* ${CMAKE_SOURCE_DIR}/ ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core && ln -snf releases/${RELEASE_TIMESTAMP} ./current
    # Symlink the main api-umbrella binary into place.
    COMMAND mkdir -p ${STAGE_PREFIX_DIR}/bin
    COMMAND cd ${STAGE_PREFIX_DIR}/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella ./api-umbrella
    # Copy all of the vendor files into place.
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor
    #COMMAND rsync -a --delete-after $(VENDOR_DIR)/ ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP} && ln -snf ../../shared/vendor ./vendor
    # Copy the precompiled assets into place.
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/shared/src/api-umbrella/web-app/public/web-assets
    COMMAND rsync -a --delete-after ${CMAKE_SOURCE_DIR}/src/api-umbrella/web-app/tmp/web-assets/ ${STAGE_EMBEDDED_DIR}/apps/core/shared/src/api-umbrella/web-app/public/web-assets/
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/src/api-umbrella/web-app/public && ln -snf ../../../../../../shared/src/api-umbrella/web-app/public/web-assets ./web-assets
    # Re-run the bundle install inside the release directory, but disabling
    # non-production gem groups. Combined with the clean flag, this deletes all
    # the test/development/asset gems we don't need for a release.
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/src/api-umbrella/web-app && env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} bundle install --path=../../../vendor/bundle --clean --without="development test assets" --deployment
    # Purge a bunch of content out of the bundler results to make for a lighter
    # release distribution. Purge gem caches, embedded test files, and
    # intermediate files used when compiling C gems from source. Also delete some
    # of the duplicate .so library files for C extensions (we should only need
    # the ones in the "extensions" directory, the rest are duplicates for legacy
    # purposes).
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/shared/vendor/bundle && rm -rf ruby/*/cache ruby/*/gems/*/test* ruby/*/gems/*/spec ruby/*/bundler/gems/*/test* ruby/*/bundler/gems/*/spec
    # Setup a shared symlink for web-app temp files.
    COMMAND mkdir -p ${STAGE_EMBEDDED_DIR}/apps/core/shared/src/api-umbrella/web-app/tmp
    COMMAND cd ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP}/src/api-umbrella/web-app && ln -snf ../../../../../shared/src/api-umbrella/web-app/tmp ./tmp
)
add_custom_target(core_release ALL DEPENDS ${STAGE_EMBEDDED_DIR}/apps/core/releases/${RELEASE_TIMESTAMP})
