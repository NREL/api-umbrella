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
  COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/admin-ui-build
  COMMAND rsync -a -v --delete-after "--filter=:- ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/.gitignore" --exclude=/dist-prod --exclude=/dist-dev ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/ ${CORE_BUILD_DIR}/tmp/admin-ui-build/
  COMMAND touch ${STAMP_DIR}/core-admin-ui-build-dir
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-npm-install
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/node_modules
  DEPENDS
    nodejs
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/package.json
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} npm install && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} npm prune
  COMMAND touch ${STAMP_DIR}/core-admin-ui-npm-install
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-bower-install
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/bower_components
  DEPENDS
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/bower.json
    ${STAMP_DIR}/core-admin-ui-npm-install
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/bower install && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/bower prune
  COMMAND touch ${STAMP_DIR}/core-admin-ui-bower-install
)

add_custom_command(
  OUTPUT ${STAMP_DIR}/core-admin-ui-build
  DEPENDS
    ${STAMP_DIR}/core-admin-ui-build-dir
    ${STAMP_DIR}/core-admin-ui-npm-install
    ${STAMP_DIR}/core-admin-ui-bower-install
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && time env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/ember build --environment=development --output-path=./dist-dev
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && time env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/ember build --environment=production --output-path=./dist-prod
  COMMAND touch ${STAMP_DIR}/core-admin-ui-build
)
