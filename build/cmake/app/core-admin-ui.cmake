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
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/package.json
  DEPENDS
    ${admin_ui_files}
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/ember-cli-build.js
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/package.json
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/yarn.lock
  COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/admin-ui-build
  COMMAND rsync -a -v --delete-after "--filter=:- ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/.gitignore" --exclude=/dist ${CMAKE_SOURCE_DIR}/src/api-umbrella/admin-ui/ ${CORE_BUILD_DIR}/tmp/admin-ui-build/
  COMMAND touch ${STAMP_DIR}/core-admin-ui-build-dir
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-yarn-install
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/node_modules
  DEPENDS
    yarn
    ${STAMP_DIR}/core-admin-ui-build-dir
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && env PATH=${DEV_INSTALL_PREFIX}/bin:${DEFAULT_PATH} yarn install --frozen-lockfile
  # In the CI environment, the "node-sass/vendor" directory seems to sometimes
  # go away. A bit of a hack, but try to workaround this by forcing node-sass
  # to be reinstalled if the vendor dir is missing.
  #
  # See:
  # https://github.com/yarnpkg/yarn/issues/1981
  # https://github.com/yarnpkg/yarn/issues/1832
  # https://github.com/sass/node-sass/issues/1579
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && test -d node_modules/node-sass && test -d node_modules/node-sass/vendor || env PATH=${DEV_INSTALL_PREFIX}/bin:${DEFAULT_PATH} yarn add node-sass --force
  COMMAND touch ${STAMP_DIR}/core-admin-ui-yarn-install
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-ui-build
    ${CORE_BUILD_DIR}/tmp/admin-ui-build/dist
  DEPENDS
    ${STAMP_DIR}/core-admin-ui-build-dir
    ${STAMP_DIR}/core-admin-ui-yarn-install
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && rm -rf ./dist && env PATH=${DEV_INSTALL_PREFIX}/bin:${DEFAULT_PATH} ./node_modules/.bin/ember build --environment=production --output-path=./dist
  COMMAND touch ${STAMP_DIR}/core-admin-ui-build
)
