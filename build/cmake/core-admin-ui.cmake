file(GLOB_RECURSE admin_ui_files
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/app/*.hbs
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/app/*.html
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/app/*.js
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/app/*.scss
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/config/*.js
  ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/lib/*.js
)
add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-build-dir
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/bower.json
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/package.json
  DEPENDS
    ${admin_ui_files}
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/bower.json
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/package.json
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/yarn.lock
  COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/admin-ui-build
  COMMAND rsync -a -v --delete-after "--filter=:- ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/.gitignore" --exclude=/dist-prod --exclude=/dist-dev ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/ ${CORE_BUILD_DIR}/tmp/admin-ui-build/
  COMMAND touch ${STAMP_DIR}/core-admin-ui-build-dir
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-yarn-install
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/node_modules
  DEPENDS
    yarn
    ${STAMP_DIR}/core-admin-ui-build-dir
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} yarn install
  COMMAND touch ${STAMP_DIR}/core-admin-ui-yarn-install
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-bower-install
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/bower_components
  DEPENDS
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/bower.json
    ${STAMP_DIR}/core-admin-ui-yarn-install
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/bower install --allow-root && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/bower prune --allow-root
  COMMAND touch ${STAMP_DIR}/core-admin-ui-bower-install
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-build
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/dist-dev
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/dist-prod
  DEPENDS
    ${STAMP_DIR}/core-admin-ui-build-dir
    ${STAMP_DIR}/core-admin-ui-yarn-install
    ${STAMP_DIR}/core-admin-ui-bower-install
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && rm -rf ./dist-dev && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/ember build --environment=development --output-path=./dist-dev
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && rm -rf ./dist-prod && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/ember build --environment=production --output-path=./dist-prod
  COMMAND touch ${STAMP_DIR}/core-admin-ui-build
)

# Normally we perform the yarn & bower installs out-of-source (so the build
# takes place entirely out of source), but if testing/development is enabled
# for this build, then also create a local symlink within the source. This then
# allows for easier interactions with the application.
if(ENABLE_TEST_DEPENDENCIES)
  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/node_modules
    DEPENDS
      ${STAMP_DIR}/core-admin-ui-yarn-install
      ${CORE_BUILD_DIR}/tmp/admin-ui-build/node_modules
    COMMAND rm -rf ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/node_modules
    COMMAND ln -snf ${CORE_BUILD_DIR}/tmp/admin-ui-build/node_modules ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/node_modules
    COMMAND touch -h ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/node_modules
  )
  add_custom_target(core-admin-ui-local-yarn ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/node_modules)

  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/bower_components
    DEPENDS
      ${STAMP_DIR}/core-admin-ui-bower-install
      ${CORE_BUILD_DIR}/tmp/admin-ui-build/bower_components
    COMMAND rm -rf ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/bower_components
    COMMAND ln -snf ${CORE_BUILD_DIR}/tmp/admin-ui-build/bower_components ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/bower_components
    COMMAND touch -h ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/bower_components
  )
  add_custom_target(core-admin-ui-local-bower ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/bower_components)
endif()
